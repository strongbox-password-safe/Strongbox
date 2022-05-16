workspace 'StrongBox'

abstract_target 'common-mac' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.12'
    use_frameworks!

    pod 'libsodium'
    pod 'Down'

    target 'Strongbox' do
      pod 'MSAL', '1.2.0'
      pod 'MSGraphClientSDK'
    end

    target 'Strongbox-Pro' do
        pod 'MSAL', '1.2.0'
        pod 'MSGraphClientSDK'
    end

    target 'Strongbox-AutoFill' do
    end

    target 'Strongbox-Pro-AutoFill' do
    end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '11.0'
    use_frameworks!

    pod 'libsodium'    
    pod 'Down'
   
    target 'Strongbox-iOS' do
        use_frameworks!

        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn', '5.0.2'

        pod 'MSGraphClientSDK'
    end

    target 'Strongbox-iOS-Pro' do
        use_frameworks!

        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'OneDriveSDK'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn', '5.0.2'

        pod 'MSGraphClientSDK'
    end    

    target 'Strongbox-iOS-SCOTUS' do
        use_frameworks!

        pod 'ISMessages'        
    end    

    target 'Strongbox-iOS-Graphene' do
        use_frameworks!

        pod 'MTBBarcodeScanner'
        pod 'ISMessages'
    end  

    target 'Strongbox-Auto-Fill' do

    end

    target 'Strongbox-Auto-Fill-Pro' do

    end

    target 'Strongbox-Auto-Fill-SCOTUS' do 

    end

    target 'Strongbox-Auto-Fill-Graphene' do 
    
    end
end

