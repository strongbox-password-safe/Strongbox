//
//  SafeStorageProviderFactory.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafeStorageProviderFactory.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"

#ifndef IS_APP_EXTENSION
#import "OneDriveStorageProvider.h"
#endif

@implementation SafeStorageProviderFactory

+ (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    if (providerId == kGoogleDrive) {
        return [GoogleDriveStorageProvider sharedInstance];
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
        NSLog(@"ADAL Onedrive Library doesn't support App Extensions. TODO: Use new ADAL! ");
        return nil;
#endif
    }
    
    [NSException raise:@"Unknown Storage Provider!" format:@"New One, Mark?"];
    
    return [LocalDeviceStorageProvider sharedInstance];
}

@end

