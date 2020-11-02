workspace 'StrongBox'

abstract_target 'common-mac' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.9'
    use_frameworks!

    pod 'KissXML'   
    pod 'libsodium'

    target 'Strongbox' do
    end

    target 'Strongbox-Outright-Pro' do
    end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '10.0'
    use_frameworks!

    pod 'libsodium'
    pod 'KissXML'

    target 'Strongbox-iOS' do
        use_frameworks!

        pod 'Reachability'
        pod 'ISMessages'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'MTBBarcodeScanner'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

    target 'Strongbox-iOS-Family' do
        use_frameworks!

        pod 'Reachability'
        pod 'ISMessages'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'MTBBarcodeScanner'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

   target 'Strongbox-Auto-Fill' do

   end

   target 'Strongbox-Auto-Fill-Family' do

   end
end
