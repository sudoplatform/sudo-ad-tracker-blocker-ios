platform :ios, '15.0'

project 'SudoAdTrackerBlocker'

target 'SudoAdTrackerBlocker' do
  use_frameworks!
  podspec :name => 'SudoAdTrackerBlocker'

  target 'SudoAdTrackerBlockerTests' do
    # Pods for testing
    podspec :name => 'SudoAdTrackerBlocker'
  end

  target 'SudoAdTrackerBlockerIntegrationTests' do
    podspec :name => 'SudoAdTrackerBlocker'
  end

# supress warnings for pods
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = "YES"
            config.build_settings['SWIFT_SUPPRESS_WARNINGS'] = "YES"
            # To fix an Xcode 14.3 issue with deployment targets less than 10
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        end
    end
end

end

