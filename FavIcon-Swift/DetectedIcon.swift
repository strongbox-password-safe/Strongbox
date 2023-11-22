//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software






import Foundation


@objc public enum DetectedIconType: UInt {
    
    case shortcut
    
    case classic
    
    case googleTV
    
    case googleAndroidChrome
    
    case appleOSXSafariTab
    
    case appleIOSWebClip
    
    case microsoftPinnedSite
    
    case webAppManifest
    
    case FBImage
}


@objc public class DetectedIcon: NSObject {
    
    @objc public let url: URL
    
    @objc public let type: DetectedIconType
    
    public let width: Int?
    
    public let height: Int?

    init(url: URL, type: DetectedIconType, width: Int? = nil, height: Int? = nil) {
        self.url = url
        self.type = type
        self.width = width
        self.height = height
    }
}
