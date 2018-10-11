//
//  SafeStorageProvider.m
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "SafeStorageProvider.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.m"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "OneDriveStorageProvider.h"

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
        return [OneDriveStorageProvider sharedInstance];
    }
    
    [NSException raise:@"Unknown Storage Provider!" format:@"New One, Mark?"];
    
    return [LocalDeviceStorageProvider sharedInstance];
}

@end
