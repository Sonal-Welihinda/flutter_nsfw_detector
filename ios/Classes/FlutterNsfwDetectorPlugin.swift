import Flutter
import UIKit
import CoreML
import Vision
import AVFoundation
import CoreVideo

/// FlutterNsfwDetectorPlugin — on-device NSFW detection using CoreML + Vision.
///
/// Bundles a compiled CoreML model (.mlmodelc) inside the plugin's iOS assets.
/// Supports scanning images (by file path or raw bytes) and videos
/// (by extracting N keyframes with fail-fast behaviour).
public class FlutterNsfwDetectorPlugin: NSObject, FlutterPlugin {

    private var visionModel: VNCoreMLModel?
    private let queue = DispatchQueue(label: "com.flutter_nsfw_detector.inference", qos: .userInitiated)

    // MARK: - FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "flutter_nsfw_detector",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterNsfwDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            queue.async { [weak self] in
                do {
                    try self?.loadModel()
                    DispatchQueue.main.async { result(nil) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "scanFile":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            queue.async { [weak self] in
                do {
                    let map = try self?.scanImageFile(filePath: filePath) ?? [:]
                    DispatchQueue.main.async { result(map) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SCAN_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "scanBytes":
            guard let args = call.arguments as? [String: Any],
                  let bytes = (args["bytes"] as? FlutterStandardTypedData)?.data else {
                result(FlutterError(code: "INVALID_ARGS", message: "bytes required", details: nil))
                return
            }
            queue.async { [weak self] in
                do {
                    let map = try self?.scanImageBytes(bytes) ?? [:]
                    DispatchQueue.main.async { result(map) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SCAN_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "scanVideo":
            guard let args = call.arguments as? [String: Any],
                  let filePath = args["filePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "filePath required", details: nil))
                return
            }
            let frameCount = args["frameCount"] as? Int ?? 5
            let threshold = (args["threshold"] as? NSNumber)?.floatValue ?? 0.5
            queue.async { [weak self] in
                do {
                    let map = try self?.scanVideoFile(filePath: filePath, frameCount: frameCount, threshold: threshold) ?? [:]
                    DispatchQueue.main.async { result(map) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SCAN_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Model Loading

    private func loadModel() throws {
        if visionModel != nil { return }

        guard let modelURL = findModelURL(named: "nsfw_model") else {
            throw NSError(domain: "FlutterNsfwDetector", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "CoreML model not found in bundle"])
        }

        let compiledURL: URL
        if modelURL.pathExtension == "mlmodelc" {
            compiledURL = modelURL
        } else {
            compiledURL = try MLModel.compileModel(at: modelURL)
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all
        let mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
        visionModel = try VNCoreMLModel(for: mlModel)
    }

    private func findModelURL(named name: String) -> URL? {
        let extensions = ["mlmodelc", "mlpackage", "mlmodel"]
        let pluginBundle = Bundle(for: FlutterNsfwDetectorPlugin.self)
        let searchBundles = [pluginBundle, Bundle.main]

        for bundle in searchBundles {
            for ext in extensions {
                if let url = bundle.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }

        // Direct path scan inside plugin framework bundle
        for ext in extensions {
            let directURL = pluginBundle.bundleURL.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }
        }

        // Search nested resource bundles
        for bundle in searchBundles {
            if let resourceBundleURL = bundle.url(forResource: "flutter_nsfw_detector", withExtension: "bundle"),
               let resourceBundle = Bundle(url: resourceBundleURL) {
                for ext in extensions {
                    if let url = resourceBundle.url(forResource: name, withExtension: ext) {
                        return url
                    }
                }
            }
        }

        // Search framework bundles
        if let frameworksPath = Bundle.main.privateFrameworksPath {
            let frameworksURL = URL(fileURLWithPath: frameworksPath)
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: frameworksURL, includingPropertiesForKeys: nil
            ) {
                for frameworkURL in contents where frameworkURL.pathExtension == "framework" {
                    let fwBundle = Bundle(url: frameworkURL)
                    for ext in extensions {
                        let modelURL = frameworkURL.appendingPathComponent("\(name).\(ext)")
                        if FileManager.default.fileExists(atPath: modelURL.path) {
                            return modelURL
                        }
                        if let url = fwBundle?.url(forResource: name, withExtension: ext) {
                            return url
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Image Scanning

    private func scanImageFile(filePath: String) throws -> [String: Any] {
        guard let image = UIImage(contentsOfFile: filePath),
              let cgImage = image.cgImage else {
            throw NSError(domain: "FlutterNsfwDetector", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not decode image: \(filePath)"])
        }
        let labels = try classify(cgImage: cgImage)
        return buildResultMap(identifier: filePath, mediaType: "image", labels: labels)
    }

    private func scanImageBytes(_ data: Data) throws -> [String: Any] {
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            throw NSError(domain: "FlutterNsfwDetector", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not decode image bytes"])
        }
        let labels = try classify(cgImage: cgImage)
        return buildResultMap(
            identifier: "bytes_\(Int(Date().timeIntervalSince1970 * 1000))",
            mediaType: "image",
            labels: labels
        )
    }

    // MARK: - Video Scanning (Fail-Fast)

    private func scanVideoFile(filePath: String, frameCount: Int, threshold: Float) throws -> [String: Any] {
        let url = URL(fileURLWithPath: filePath)
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration > 0 else {
            throw NSError(domain: "FlutterNsfwDetector", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not read video duration"])
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 224, height: 224)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        let interval = duration / Double(frameCount + 1)
        var maxNsfwScore: Float = 0
        var finalLabels: [[String: Any]] = []
        var framesScanned = 0

        for i in 1...frameCount {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let labels = try classify(cgImage: cgImage)
                framesScanned += 1

                let nsfwScore = labels
                    .first(where: { ($0["category"] as? String) == "nudity" })
                    .flatMap { $0["confidence"] as? Float } ?? 0

                if nsfwScore > maxNsfwScore {
                    maxNsfwScore = nsfwScore
                    finalLabels = labels
                }

                // Fail-fast: stop if NSFW detected
                if nsfwScore >= threshold { break }
            } catch {
                // Skip failed frames
                continue
            }
        }

        var resultMap = buildResultMap(identifier: filePath, mediaType: "video", labels: finalLabels)
        resultMap["frameCount"] = framesScanned
        return resultMap
    }

    // MARK: - CoreML / Vision Inference

    private func classify(cgImage: CGImage) throws -> [[String: Any]] {
        guard let model = visionModel else {
            throw NSError(domain: "FlutterNsfwDetector", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "Model not loaded. Call initialize() first."])
        }

        var classificationResult: [[String: Any]] = []
        var classificationError: Error?

        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                classificationError = error
                return
            }
            guard let results = request.results, !results.isEmpty else { return }

            // Case 1: VNClassificationObservation (classifier models)
            if let classificationResults = results as? [VNClassificationObservation] {
                let raws = classificationResults.map { Float($0.confidence) }
                let probs = Self.softmax(raws)
                classificationResult = zip(classificationResults, probs)
                    .sorted { $0.1 > $1.1 }
                    .map { (obs, prob) in
                        [
                            "category": Self.canonicalCategory(obs.identifier),
                            "confidence": prob,
                        ] as [String: Any]
                    }
                return
            }

            // Case 2: MultiArray output (e.g. OpenNSFW2)
            if let featureResult = results.first as? VNCoreMLFeatureValueObservation,
               let multiArray = featureResult.featureValue.multiArrayValue {
                classificationResult = Self.parseMultiArrayOutput(multiArray)
            }
        }
        request.imageCropAndScaleOption = .scaleFit

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        if let error = classificationError { throw error }
        return classificationResult
    }

    // MARK: - Output Parsing

    private static func parseMultiArrayOutput(_ array: MLMultiArray) -> [[String: Any]] {
        let count = array.count
        if count >= 2 {
            let raw0 = Float(truncating: array[0])
            let raw1 = Float(truncating: array[1])
            let (sfwConf, nsfwConf) = normaliseConfidencePair(raw0, raw1)
            return [
                ["category": "safe", "confidence": sfwConf],
                ["category": "nudity", "confidence": nsfwConf],
            ].sorted { ($0["confidence"] as! Float) > ($1["confidence"] as! Float) }
        }
        return []
    }

    private static func normaliseConfidencePair(_ a: Float, _ b: Float) -> (Float, Float) {
        let sum = a + b
        let bothInRange = a >= 0 && a <= 1 && b >= 0 && b <= 1
        let looksLikeProbs = bothInRange && abs(sum - 1.0) < 0.05
        if looksLikeProbs { return (a, b) }
        let probs = softmax([a, b])
        return (probs[0], probs[1])
    }

    private static func softmax(_ values: [Float]) -> [Float] {
        guard !values.isEmpty else { return [] }
        let maxVal = values.max() ?? 0
        let exps = values.map { Foundation.exp($0 - maxVal) }
        let sum = exps.reduce(0, +)
        guard sum > 0 else {
            return Array(repeating: 1.0 / Float(values.count), count: values.count)
        }
        return exps.map { $0 / sum }
    }

    private static func canonicalCategory(_ identifier: String) -> String {
        let lower = identifier.lowercased()
        if lower.contains("nsfw") || lower.contains("nudity") || lower.contains("nude") || lower.contains("porn") || lower.contains("sexy") || lower.contains("hentai") {
            return "nudity"
        }
        if lower.contains("safe") || lower.contains("sfw") || lower.contains("neutral") || lower.contains("normal") || lower.contains("drawing") {
            return "safe"
        }
        return lower
    }

    // MARK: - Helpers

    private func buildResultMap(
        identifier: String,
        mediaType: String,
        labels: [[String: Any]]
    ) -> [String: Any] {
        return [
            "identifier": identifier,
            "mediaType": mediaType,
            "labels": labels,
            "frameCount": 1,
        ]
    }
}
