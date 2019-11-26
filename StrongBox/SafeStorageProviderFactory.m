//
//  SafeStorageProviderFactory.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafeStorageProviderFactory.h"
#import "DropboxV2StorageProvider.h"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"

#ifndef IS_APP_EXTENSION

#import "OneDriveStorageProvider.h"
#import "GoogleDriveStorageProvider.h"

#endif

@implementation SafeStorageProviderFactory

+ (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    if (providerId == kGoogleDrive) {
#ifndef IS_APP_EXTENSION
        return [GoogleDriveStorageProvider sharedInstance];
#else
        NSLog(@"Google's new Library doesn't support App Extensions...");
        return nil;
#endif
    }
    else if (providerId == kDropbox)
    {
        return [DropboxV2StorageProvider sharedInstance];
    }
    else if (providerId == kiCloud) {
        return [AppleICloudProvider sharedInstance];
    }
    else if (providerId == kLocalDevice)
    {
        return [LocalDeviceStorageProvider sharedInstance];
    }
    else if(providerId == kOneDrive) {
#ifndef IS_APP_EXTENSION
        return [OneDriveStorageProvider sharedInstance];
#else
        NSLog(@"ADAL Onedrive Library doesn't support App Extensions. FUTURE: Use new ADAL! ");
        return nil;
#endif
    }
    else if(providerId == kFilesAppUrlBookmark) {
        return FilesAppUrlBookmarkProvider.sharedInstance;
    }
    else if(providerId == kSFTP) {
        return SFTPStorageProvider.sharedInstance;
    }
    else if(providerId == kWebDAV) {
        return WebDAVStorageProvider.sharedInstance;
    }
    
    [NSException raise:@"Unknown Storage Provider!" format:@"New One, Mark?"];
    
    return [LocalDeviceStorageProvider sharedInstance];
}

@end

