target 'SudoAdTrackerBlocker' do
  use_frameworks!

  platform :ios, '13.0'

  podspec :name => 'SudoAdTrackerBlocker'

  target 'SudoAdTrackerBlockerTests' do
    # Pods for testing
    podspec :name => 'SudoAdTrackerBlocker'
  end

  target 'SudoAdTrackerBlockerIntegrationTests' do
    # Pods for testing
    podspec :name => 'SudoAdTrackerBlocker'
  end

# supress warnings for pods
post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = "YES"
            config.build_settings['SWIFT_SUPPRESS_WARNINGS'] = "YES"
        end
    end
end

end

