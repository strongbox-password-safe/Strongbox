workspace 'StrongBox'

use_frameworks!

abstract_target 'common-mac' do
  project 'macbox/MacBox.xcodeproj'
  platform :osx, '12.0'
  
  pod 'SwiftCBOR'
  
  target 'Mac-Freemium' do
    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'ObjectiveDropboxOfficial'
  end
  
  target 'Mac-Pro' do
    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'ObjectiveDropboxOfficial'
  end
  
  target 'Mac-Unified-Freemium' do
    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'ObjectiveDropboxOfficial'
  end
  
  target 'Mac-Unified-Pro' do
    pod 'GoogleAPIClientForREST/Drive'
    pod 'GoogleSignIn'
    pod 'ObjectiveDropboxOfficial'
  end
  
  target 'Mac-Graphene' do
    
  end
  
  target 'Mac-Business' do
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
  
  target 'Mac-Graphene-AutoFill' do
  end
  
  target 'Mac-Business-AutoFill' do
  end
end

abstract_target 'common-ios' do
    project 'Strongbox.xcodeproj'
    platform :ios, '15.0'
    
    pod 'SwiftCBOR'
    
    target 'Strongbox-iOS' do
        pod 'ISMessages'
        pod 'ObjectiveDropboxOfficial'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

    target 'Strongbox-iOS-Pro' do
        pod 'ISMessages'
        pod 'ObjectiveDropboxOfficial'
        pod 'GoogleAPIClientForREST/Drive'
        pod 'GoogleSignIn'
    end

    target 'Strongbox-iOS-Business' do
      pod 'ISMessages'
      pod 'ObjectiveDropboxOfficial'
      pod 'GoogleAPIClientForREST/Drive'
      pod 'GoogleSignIn'
    end

    target 'Strongbox-iOS-SCOTUS' do
        pod 'ISMessages'
    end    

    target 'Strongbox-iOS-Graphene' do
        pod 'ISMessages'
    end  

    target 'Strongbox-Auto-Fill' do

    end

    target 'Strongbox-Auto-Fill-Pro' do

    end

    target 'Strongbox-Auto-Fill-Business' do
      
    end
    
    target 'Strongbox-Auto-Fill-SCOTUS' do 

    end

    target 'Strongbox-Auto-Fill-Graphene' do 
    
    end
end

# XCode 14 issue...
# From: https://github.com/fastlane/fastlane/issues/20670
# Also: https://support.bitrise.io/hc/en-us/articles/4406551563409-CocoaPods-frameworks-signing-issue

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
        target.build_configurations.each do |config|
          config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        end
      end
    end
  end
  
  #  Fix XCode 14.3 Issue
  
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end
  
  # Fix XCode 15 issues

  installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
      xcconfig_path = config.base_configuration_reference.real_path
      xcconfig = File.read(xcconfig_path)
      xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
      File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
      end
  end
end
