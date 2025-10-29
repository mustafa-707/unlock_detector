#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unlock_detector.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unlock_detector'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for detecting device lock/unlock events'
  s.description      = <<-DESC
A Flutter plugin that detects device lock and unlock events on iOS and Android.
On iOS, uses data protection notifications for lock detection (limited functionality).
On Android, provides reliable lock/unlock detection via system broadcasts.
                       DESC
  s.homepage         = 'https://github.com/yourusername/unlock_detector'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  
  # Updated to iOS 12.0+ (covers all modern devices)
  s.platform = :ios, '12.0'

  # Swift version
  s.swift_version = '5.9'  # Updated to latest stable Swift

  # Modern Xcode configuration
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',  # Exclude 32-bit simulator
    'SWIFT_VERSION' => '5.9'
  }
  
  # iOS deployment target
  s.ios.deployment_target = '12.0'
end
