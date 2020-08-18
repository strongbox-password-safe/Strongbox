//
//  SafeStorageProviderFactory.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SafeStorageProviderFactory.h"
#import "LocalDeviceStorageProvider.h"

#ifndef IS_APP_EXTENSION

#import "DropboxV2StorageProvider.h"
#import "AppleICloudProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"
#import "OneDriveStorageProvider.h"
#import "GoogleDriveStorageProvider.h"

#endif

@implementation SafeStorageProviderFactory

#ifndef IS_APP_EXTENSION

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

#else

+ (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    [NSException raise:@"Storage Provider Called From Auto Fill!!" format:@"Very Bad"];
    return nil;
}

#endif

+ (NSString*)getStorageDisplayName:(SafeMetaData*)database {
    return [SafeStorageProviderFactory getDisplayNameForProvider:database.storageProvider database:database];
}

+ (NSString*)getStorageDisplayNameForProvider:(StorageProvider)provider {
    return [SafeStorageProviderFactory getDisplayNameForProvider:provider database:nil];
}

+ (NSString*)getDisplayNameForProvider:(StorageProvider)provider database:(SafeMetaData*)database {
    NSString* _displayName;
    
    if (provider == kGoogleDrive) {
        _displayName = NSLocalizedString(@"storage_provider_name_google_drive", @"Google Drive");
        if([_displayName isEqualToString:@"storage_provider_name_google_drive"]) {
            _displayName = @"Google Drive";
        }
    }
    else if (provider == kDropbox) {
        _displayName = NSLocalizedString(@"storage_provider_name_dropbox", @"Dropbox");
        if([_displayName isEqualToString:@"storage_provider_name_dropbox"]) {
            _displayName = @"Dropbox";
        }
        return _displayName;
    }
    else if (provider == kiCloud) {
        _displayName = NSLocalizedString(@"storage_provider_name_icloud", @"iCloud");
        if([_displayName isEqualToString:@"storage_provider_name_icloud"]) {
            _displayName = @"iCloud";
        }
    }
    else if (provider == kLocalDevice) {
        if (database) {
            _displayName = [LocalDeviceStorageProvider.sharedInstance isUsingSharedStorage:database] ?
                NSLocalizedString(@"autofill_safes_vc_storage_local_name", @"Local") :
                NSLocalizedString(@"autofill_safes_vc_storage_local_docs_name", @"Local (Documents)");
        }
        else {
            _displayName = NSLocalizedString(@"storage_provider_name_local_device", @"Local Device");
            if([_displayName isEqualToString:@"storage_provider_name_local_device"]) {
                _displayName = @"Local Device";
            }
        }
    }
    else if(provider == kOneDrive) {
        _displayName = NSLocalizedString(@"storage_provider_name_onedrive", @"OneDrive");
        if([_displayName isEqualToString:@"storage_provider_name_onedrive"]) {
            _displayName = @"OneDrive";
        }
    }
    else if(provider == kFilesAppUrlBookmark) {
        _displayName = NSLocalizedString(@"storage_provider_name_ios_files", @"iOS Files");
        if([_displayName isEqualToString:@"storage_provider_name_ios_files"]) {
            _displayName = @"iOS Files";
        }
    }
    else if(provider == kSFTP) {
        _displayName = NSLocalizedString(@"storage_provider_name_sftp", @"SFTP");
        if([_displayName isEqualToString:@"storage_provider_name_sftp"]) {
            _displayName = @"SFTP";
        }
    }
    else if(provider == kWebDAV) {
        _displayName = NSLocalizedString(@"storage_provider_name_webdav", @"WebDAV");
        if([_displayName isEqualToString:@"storage_provider_name_webdav"]) {
            _displayName = @"WebDAV";
        }
    }
    else {
        _displayName = @"SafeStorageProviderFactory::getDisplayName Unknown";
    }
    
    return _displayName;
}

+ (NSString*)getIcon:(SafeMetaData*)database {
    return [SafeStorageProviderFactory getIconForProvider:database.storageProvider];
}

+ (NSString*)getIconForProvider:(StorageProvider)provider {
    if (provider == kGoogleDrive) {
        return @"product32";
    }
    else if (provider == kDropbox) {
        return @"dropbox-blue-32x32-nologo";
    }
    else if (provider == kiCloud) {
        return @"icloud-32";
    }
    else if (provider == kLocalDevice) {
        return @"iphone_x";
    }
    else if(provider == kOneDrive) {
        return @"one-drive-icon-only-32x32";
    }
    else if(provider == kFilesAppUrlBookmark) {
        return @"lock";
    }
    else if(provider == kSFTP) {
        return @"sftp-32x32";
    }
    else if(provider == kWebDAV) {
        return @"webdav-32x32";
    }
    else {
        return @"SafeStorageProviderFactory::getIcon Unknown";
    }
}

@end

