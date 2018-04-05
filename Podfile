workspace 'StrongBox'

project 'Strongbox.xcodeproj'
project 'macbox/MacBox.xcodeproj'

target 'Strongbox' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.9'
    use_frameworks!

    pod 'SAMKeychain'
end

target 'Strongbox-iOS' do
    project 'Strongbox.xcodeproj'
    platform :ios, '9.2'
    use_frameworks!

    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'JNKeychain'
    pod 'ISMessages'
    pod 'SVProgressHUD'  
    pod 'Reachability'
    pod 'ObjectiveDropboxOfficial'
    pod 'DZNEmptyDataSet'
    pod 'PopupDialog'
end

