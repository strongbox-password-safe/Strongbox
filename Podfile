workspace 'StrongBox'

target 'Strongbox' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.9'
    use_frameworks!

    pod 'SAMKeychain'
    pod 'libsodium'
    pod 'GZIP'
end

pre_install do |installer|
    pod_targets = installer.pod_targets.flat_map do |pod_target|
        pod_target.name == "SVProgressHUD" ? pod_target.scoped : pod_target
    end
    installer.aggregate_targets.each do |aggregate_target|
        aggregate_target.pod_targets = pod_targets.select do |pod_target|
            pod_target.target_definitions.include?(aggregate_target.target_definition)
        end
    end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '9.2'
    use_frameworks!

    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'JNKeychain'
    pod 'ObjectiveDropboxOfficial'
    pod 'DZNEmptyDataSet'
    pod 'Reachability'
    pod 'GZIP'
    pod 'libsodium'    
    
    target 'Strongbox-iOS' do
        pod 'ISMessages' 
        pod 'PopupDialog'
        pod 'SVProgressHUD' 
        pod 'OneDriveSDK'
    end

    target 'Strongbox Auto Fill' do
        pod 'SVProgressHUD'
    end
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        #puts "#{target.name}"
        if target.name == "SVProgressHUD-Pods-common-ios-Strongbox Auto Fill"
            puts "Adding SV_APP_EXTENSIONS"    
            target.build_configurations.each do |config|
                config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
                config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'SV_APP_EXTENSIONS'
            end
        end
    end
end
