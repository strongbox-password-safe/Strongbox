workspace 'StrongBox'

use_frameworks!

abstract_target 'common-mac' do
    project 'macbox/MacBox.xcodeproj'
    platform :osx, '10.15'
    
    pod 'libsodium'
    pod 'Down'

    target 'Mac-Freemium' do
      pod 'MSAL'
      pod 'MSGraphClientSDK'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'GoogleSignIn'
      pod 'ObjectiveDropboxOfficial'
    end

    target 'Mac-Pro' do
        pod 'MSAL'
        pod 'MSGraphClientSDK'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
        pod 'ObjectiveDropboxOfficial'
    end

    target 'Mac-Unified-Freemium' do
      pod 'MSAL'
      pod 'MSGraphClientSDK'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'GoogleSignIn'
      pod 'ObjectiveDropboxOfficial'
    end

    target 'Mac-Unified-Pro' do
      pod 'MSAL'
      pod 'MSGraphClientSDK'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'GoogleSignIn'
      pod 'ObjectiveDropboxOfficial'
    end

    target 'Mac-Freemium-AutoFill' do
    end

    target 'Mac-Unified-Freemium-AutoFill' do
    end
    
    target 'Mac-Unified-Pro-AutoFill' do
    end

    target 'Mac-Pro-AutoFill' do
    end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '11.0'

    pod 'libsodium'    
    pod 'Down'
   
    target 'Strongbox-iOS' do
        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
        pod 'MSAL'
        pod 'MSGraphClientSDK'
    end

    target 'Strongbox-iOS-Pro' do
        pod 'ISMessages'
        pod 'MTBBarcodeScanner'
        pod 'ObjectiveDropboxOfficial'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
        pod 'MSAL'
        pod 'MSGraphClientSDK'
    end    

    target 'Strongbox-iOS-SCOTUS' do
        pod 'ISMessages'
    end    

    target 'Strongbox-iOS-Graphene' do
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

