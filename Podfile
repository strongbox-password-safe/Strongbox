workspace 'StrongBox'

target 'Strongbox' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.9'
    use_frameworks!

    pod 'SAMKeychain'
#    pod 'KKDomain', :git => 'https://github.com/kejinlu/KKDomain.git'
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '9.2'
    use_frameworks!

    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'JNKeychain'
    pod 'ObjectiveDropboxOfficial'

    target 'Strongbox-iOS' do
        pod 'ISMessages' 
        pod 'Reachability'
        pod 'DZNEmptyDataSet'
        pod 'PopupDialog'
        pod 'ADAL', '~> 1.2'
        pod 'Base32', '~> 1.1'
        pod 'SVProgressHUD' 
    end

    target 'Strongbox Auto Fill' do
    end
end

