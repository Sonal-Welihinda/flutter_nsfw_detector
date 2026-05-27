package lk.sonal.flutter_nsfw_detector

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.media.MediaMetadataRetriever
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import org.tensorflow.lite.Interpreter
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * FlutterNsfwDetectorPlugin — on-device NSFW detection using LiteRT (TFLite).
 *
 * Bundles a MobileNet-based NSFW classifier (.tflite) inside the plugin's
 * Android assets. Supports scanning images (by file path or raw bytes) and
 * videos (by extracting N keyframes with fail-fast behaviour).
 */
class FlutterNsfwDetectorPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var interpreter: Interpreter? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    companion object {
        private const val CHANNEL_NAME = "flutter_nsfw_detector"
        private const val MODEL_ASSET = "nsfw_model.tflite"
        private const val INPUT_SIZE = 224
        private const val OUTPUT_SIZE = 2
    }

    // ── FlutterPlugin lifecycle ──────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        interpreter?.close()
        interpreter = null
        scope.cancel()
    }

    // ── MethodCallHandler ────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                scope.launch {
                    try {
                        loadModel()
                        withContext(Dispatchers.Main) { result.success(null) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("INIT_FAILED", e.message, null)
                        }
                    }
                }
            }

            "scanFile" -> {
                val filePath = (call.arguments as? Map<*, *>)?.get("filePath") as? String
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath required", null)
                    return
                }
                scope.launch {
                    try {
                        val map = scanImageFile(filePath)
                        withContext(Dispatchers.Main) { result.success(map) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SCAN_FAILED", e.message, null)
                        }
                    }
                }
            }

            "scanBytes" -> {
                val bytes = (call.arguments as? Map<*, *>)?.get("bytes") as? ByteArray
                if (bytes == null) {
                    result.error("INVALID_ARGS", "bytes required", null)
                    return
                }
                scope.launch {
                    try {
                        val map = scanImageBytes(bytes)
                        withContext(Dispatchers.Main) { result.success(map) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SCAN_FAILED", e.message, null)
                        }
                    }
                }
            }

            "scanVideo" -> {
                val args = call.arguments as? Map<*, *>
                val filePath = args?.get("filePath") as? String
                val frameCount = (args?.get("frameCount") as? Number)?.toInt() ?: 5
                val threshold = (args?.get("threshold") as? Number)?.toFloat() ?: 0.5f
                if (filePath == null) {
                    result.error("INVALID_ARGS", "filePath required", null)
                    return
                }
                scope.launch {
                    try {
                        val map = scanVideoFile(filePath, frameCount, threshold)
                        withContext(Dispatchers.Main) { result.success(map) }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SCAN_FAILED", e.message, null)
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    // ── Model loading ────────────────────────────────────────────────────

    @Synchronized
    private fun loadModel() {
        if (interpreter != null) return
        val assetFd = context.assets.openFd(MODEL_ASSET)
        val inputStream = assetFd.createInputStream()
        val bytes = inputStream.readBytes()
        inputStream.close()
        val buffer = ByteBuffer.allocateDirect(bytes.size).apply {
            order(ByteOrder.nativeOrder())
            put(bytes)
            rewind()
        }
        interpreter = Interpreter(buffer, Interpreter.Options())
    }

    // ── Image scanning ───────────────────────────────────────────────────

    private fun scanImageFile(filePath: String): Map<String, Any> {
        val bitmap = BitmapFactory.decodeFile(filePath)
            ?: throw Exception("Could not decode image: $filePath")
        try {
            val labels = classify(bitmap)
            return buildResultMap(filePath, "image", labels)
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    private fun scanImageBytes(bytes: ByteArray): Map<String, Any> {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw Exception("Could not decode image bytes")
        try {
            val labels = classify(bitmap)
            return buildResultMap("bytes_${System.currentTimeMillis()}", "image", labels)
        } finally {
            if (!bitmap.isRecycled) bitmap.recycle()
        }
    }

    // ── Video scanning (fail-fast) ───────────────────────────────────────

    private fun scanVideoFile(filePath: String, frameCount: Int, threshold: Float): Map<String, Any> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(filePath)
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L

            if (durationMs <= 0) throw Exception("Could not read video duration")

            val interval = durationMs * 1000L / (frameCount + 1) // in microseconds
            var maxNsfwScore = 0f
            var finalLabels = listOf<Map<String, Any>>()
            var framesScanned = 0

            for (i in 1..frameCount) {
                val timeUs = interval * i
                val bitmap = retriever.getFrameAtTime(
                    timeUs,
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                ) ?: continue

                try {
                    val labels = classify(bitmap)
                    framesScanned++
                    val nsfwScore = labels.firstOrNull {
                        it["category"] == "nudity"
                    }?.get("confidence") as? Float ?: 0f

                    if (nsfwScore > maxNsfwScore) {
                        maxNsfwScore = nsfwScore
                        finalLabels = labels
                    }

                    // Fail-fast: if any frame is NSFW, stop immediately
                    if (nsfwScore >= threshold) break
                } finally {
                    if (!bitmap.isRecycled) bitmap.recycle()
                }
            }

            val result = buildResultMap(filePath, "video", finalLabels)
            return result + mapOf("frameCount" to framesScanned)
        } finally {
            retriever.release()
        }
    }

    // ── TFLite inference ─────────────────────────────────────────────────

    private fun classify(bitmap: Bitmap): List<Map<String, Any>> {
        val interp = interpreter ?: throw Exception("Model not loaded. Call initialize() first.")

        val resized = if (bitmap.width == INPUT_SIZE && bitmap.height == INPUT_SIZE) {
            bitmap
        } else {
            Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, true)
        }

        val inputBuffer = ByteBuffer.allocateDirect(1 * INPUT_SIZE * INPUT_SIZE * 3 * 4).apply {
            order(ByteOrder.nativeOrder())
        }

        try {
            for (y in 0 until INPUT_SIZE) {
                for (x in 0 until INPUT_SIZE) {
                    val pixel = resized.getPixel(x, y)
                    inputBuffer.putFloat(Color.red(pixel) / 255f)
                    inputBuffer.putFloat(Color.green(pixel) / 255f)
                    inputBuffer.putFloat(Color.blue(pixel) / 255f)
                }
            }
            inputBuffer.rewind()

            val outputArray = Array(1) { FloatArray(OUTPUT_SIZE) }
            interp.run(inputBuffer, outputArray)
            return parseOutput(outputArray[0])
        } finally {
            if (resized !== bitmap && !resized.isRecycled) resized.recycle()
        }
    }

    private fun parseOutput(raw: FloatArray): List<Map<String, Any>> {
        if (raw.size >= 2) {
            return listOf(
                mapOf("category" to "safe", "confidence" to raw[0]),
                mapOf("category" to "nudity", "confidence" to raw[1]),
            ).sortedByDescending { it["confidence"] as Float }
        }
        return emptyList()
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private fun buildResultMap(
        identifier: String,
        mediaType: String,
        labels: List<Map<String, Any>>
    ): Map<String, Any> = mapOf(
        "identifier" to identifier,
        "mediaType" to mediaType,
        "labels" to labels,
        "frameCount" to 1,
    )
}
