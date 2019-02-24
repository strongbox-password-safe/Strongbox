Pod::Spec.new do |spec|
  spec.name         = 'FavIcon'
  spec.version      = '2.4'
  spec.homepage     = 'https://github.com/nhahn/FavIcon'
  spec.summary      = 'FavIcon is a tiny Swift library for downloading the favicon representing a website.'
  spec.authors      = { 'Leon Breedt' => 'https://github.com/bitserf' }

  spec.ios.deployment_target = '8.0'
  spec.source       = { :git => "https://github.com/nhahn/FavIcon.git", :branch => "master"}
  spec.source_files = 'FavIcon/**/*.{h,m,swift}', 'LibXML2/**/*.{h,m}'
  spec.framework    = 'Foundation', 'UIKit'
  spec.library  = 'xml2'
  spec.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2', 'ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES' }
end
