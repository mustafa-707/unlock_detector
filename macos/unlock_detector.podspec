#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unlock_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unlock_detector'
  s.version          = '1.2.0'
  s.summary          = 'Flutter plugin for foreground/background, idle and lock/unlock detection.'
  s.description      = <<-DESC
A Flutter plugin that detects app foreground/background, idle, and device
lock/unlock — for user online/offline presence.
                       DESC
  s.homepage         = 'https://github.com/mustafa-707/unlock_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'mustafa-707' => 'https://github.com/mustafa-707' }

  s.source           = { :path => '.' }
  s.source_files = 'unlock_detector/Sources/unlock_detector/**/*'
  s.resource_bundles = { 'unlock_detector_privacy' => ['unlock_detector/Sources/unlock_detector/PrivacyInfo.xcprivacy'] }

  s.dependency 'FlutterMacOS'
  s.frameworks = 'IOKit'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
