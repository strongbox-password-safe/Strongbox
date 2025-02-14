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
    kLocalDevice,
    kiCloud,
    kOneDrive_Deprecated,
    kFilesAppUrlBookmark,
    kSFTP,
    kWebDAV,
    kOneDrive,
    kWiFiSync,
    kCloudKit,
    /* ---- */
    kStorageProviderCount
};

#endif /* StorageProvider_h */
