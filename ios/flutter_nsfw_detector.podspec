#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_nsfw_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_nsfw_detector'
  s.version          = '0.0.1'
  s.summary          = 'On-device NSFW content detection for Flutter using CoreML (iOS) and TFLite (Android).'
  s.description      = <<-DESC
Privacy-first, on-device NSFW content detection plugin for Flutter.
Uses CoreML on iOS and LiteRT (TFLite) on Android. Supports images and videos.
Includes a ready-to-use NsfwGuardWidget for seamless UI integration.
                       DESC
  s.homepage         = 'https://github.com/example/flutter_nsfw_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.resources        = ['Assets/**/*']
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'CoreML', 'Vision', 'AVFoundation', 'CoreVideo'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
