//
//  MacUrlSchemes.h
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kStrongboxSFTPUrlScheme;
extern NSString* const kStrongboxWebDAVUrlScheme;

extern NSString* const kStrongboxFileUrlScheme;
extern NSString* const kStrongboxSyncManagedFileUrlScheme;

extern NSString* const kStrongboxOneDriveUrlScheme;
extern NSString* const kStrongboxGoogleDriveUrlScheme;
extern NSString* const kStrongboxDropboxUrlScheme;

extern NSString* const kStrongboxWiFiSyncUrlScheme;
extern NSString* const kStrongboxCloudUrlScheme;

StorageProvider storageProviderFromUrl(NSURL* url);
StorageProvider storageProviderFromUrlScheme(NSString* scheme);
NSString* schemeFromStorageProvider(StorageProvider storageProvider);

NSURL* fileUrlFromManagedUrl(NSURL* managedUrl);
NSURL* managedUrlFromFileUrl(NSURL* fileUrl);

NSString* getPathRelativeToUserHome(NSString* path);
NSString* getFriendlyICloudPath(NSString* path);
    
NS_ASSUME_NONNULL_END
