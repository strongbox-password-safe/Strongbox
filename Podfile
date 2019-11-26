workspace 'StrongBox'

target 'Strongbox' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.9'
    use_frameworks!

    pod 'KissXML'
    pod 'SAMKeychain'
    pod 'libsodium'
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '10.0'
    use_frameworks!

    pod 'JNKeychain'
    pod 'ObjectiveDropboxOfficial'
    pod 'DZNEmptyDataSet'
    pod 'Reachability'
    pod 'libsodium'    
    pod 'KissXML'

    target 'Strongbox-iOS' do
        use_frameworks!
      
        pod 'ISMessages'
        pod 'OneDriveSDK'
        pod 'MTBBarcodeScanner'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

    target 'Strongbox-iOS Family' do
        use_frameworks!

        pod 'ISMessages'
        pod 'OneDriveSDK'
        pod 'MTBBarcodeScanner'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

   target 'Strongbox Auto Fill' do

   end

   target 'Strongbox Auto Fill Family' do

   end
end
