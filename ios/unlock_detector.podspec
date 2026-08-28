#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unlock_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unlock_detector'
  s.version          = '1.3.0'
  s.summary          = 'Flutter plugin for detecting device lock/unlock and app foreground/background events.'
  s.description      = <<-DESC
A Flutter plugin that detects device lock/unlock and app foreground/background
transitions — useful for user presence (online/offline) tracking.
                       DESC
  s.homepage         = 'https://github.com/mustafa-707/unlock_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'mustafa-707' => 'https://github.com/mustafa-707' }
  s.source           = { :path => '.' }
  s.source_files     = 'unlock_detector/Sources/unlock_detector/**/*.swift'
  s.resource_bundles = { 'unlock_detector_privacy' => ['unlock_detector/Sources/unlock_detector/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.ios.deployment_target = '13.0'
end
