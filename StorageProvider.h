//
//  StorageProvider.h
//  Strongbox
//
//  Created by Mark on 04/04/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef StorageProvider_h
#define StorageProvider_h

typedef NS_ENUM (NSUInteger, StorageProvider) {
    kGoogleDrive,
    kDropbox,
#if TARGET_OS_IPHONE
    kLocalDevice,
#else
    kMacFile,
#endif
    kiCloud,
    kOneDrive_Deprecated,
    kFilesAppUrlBookmark,
    kSFTP,
    kWebDAV,
      
    kTwoDrive,
    /* ---- */
    kStorageProviderCount
};

#endif /* StorageProvider_h */
