//
//  SafeStorageProviderFactory.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SafeStorageProviderFactory.h"


#if TARGET_OS_IPHONE

#import "LocalDeviceStorageProvider.h"

#ifndef IS_APP_EXTENSION

#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"
#import "AppleICloudProvider.h"
#import "FilesAppUrlBookmarkProvider.h"

#endif

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS

#import "OneDriveStorageProvider.h"
#import "GoogleDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"

#endif

#else

#import "MacUrlSchemes.h"
#import "MacFileBasedBookmarkStorageProvider.h"
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"

#endif

@implementation SafeStorageProviderFactory

#ifndef IS_APP_EXTENSION

+ (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    if(providerId == kWebDAV) {
        return WebDAVStorageProvider.sharedInstance;
    }
    else if(providerId == kSFTP) {
        return SFTPStorageProvider.sharedInstance;
    }
#if TARGET_OS_IPHONE
    else if (providerId == kiCloud) {
        return [AppleICloudProvider sharedInstance];
    }
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    else if (providerId == kGoogleDrive) {
        return [GoogleDriveStorageProvider sharedInstance];
    }
    else if (providerId == kDropbox)
    {
        return [DropboxV2StorageProvider sharedInstance];
    }
    else if(providerId == kOneDrive) {
        return [OneDriveStorageProvider sharedInstance];
    }
#endif
    else if(providerId == kFilesAppUrlBookmark) {
        return FilesAppUrlBookmarkProvider.sharedInstance;
    }
    else if (providerId == kLocalDevice)
    {
        return [LocalDeviceStorageProvider sharedInstance];
    }
#elif TARGET_OS_OSX
    else if (providerId == kMacFile) {
        return MacFileBasedBookmarkStorageProvider.sharedInstance;
    }
#endif
    
    NSLog(@"WARNWARN: Unknown Storage Provider!");
    return nil;
}

#else

+ (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    [NSException raise:@"Storage Provider Called From AutoFill!!" format:@"Very Bad"];
    return nil;
}

#endif

+ (NSString*)getStorageDisplayName:(METADATA_PTR )database {
    return [SafeStorageProviderFactory getDisplayNameForProvider:database.storageProvider database:database];
}

+ (NSString*)getStorageDisplayNameForProvider:(StorageProvider)provider {
    return [SafeStorageProviderFactory getDisplayNameForProvider:provider database:nil];
}

+ (NSString*)getDisplayNameForProvider:(StorageProvider)provider database:(METADATA_PTR )database {
    NSString* _displayName;
    
    if (provider == kiCloud) {
        _displayName = NSLocalizedString(@"storage_provider_name_icloud", @"iCloud");
        if([_displayName isEqualToString:@"storage_provider_name_icloud"]) {
            _displayName = @"iCloud";
        }
    }
#if TARGET_OS_IPHONE
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
#else
    else if (provider == kMacFile) {
        if (database) {
            if ( [database.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
                _displayName = NSLocalizedString(@"storage_provider_name_mac_file_short", @"File");
            }
            else {
                _displayName = NSLocalizedString(@"storage_provider_name_mac_file_short", @"File");
                _displayName = [_displayName stringByAppendingString:@"*"];
            }
        }
        else {
            _displayName = NSLocalizedString(@"storage_provider_name_mac_file_short", @"File");
        }
    }
#endif
    else if (provider == kGoogleDrive) {
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
#if TARGET_OS_IPHONE
        _displayName = NSLocalizedString(@"storage_provider_name_webdav", @"WebDAV");
        if([_displayName isEqualToString:@"storage_provider_name_webdav"]) {
            _displayName = @"WebDAV";
        }
#else
            _displayName = @"DAV"; 
#endif
    }
    else {
        _displayName = @"SafeStorageProviderFactory::getDisplayName Unknown";
    }
    
    return _displayName;
}

+ (NSString*)getIcon:(METADATA_PTR )database {
    return [SafeStorageProviderFactory getIconForProvider:database.storageProvider];
}

+ (NSString*)getIconForProvider:(StorageProvider)provider {
    if (provider == kiCloud) {
        return @"cloud";
    }
#if TARGET_OS_IPHONE
    else if (provider == kLocalDevice) {
        return @"iphone_x";
    }
#endif
    else if (provider == kGoogleDrive) {
        return @"google-drive-2021";
    }
    else if (provider == kDropbox) {
        return @"Dropbox-2021";
    }
    else if(provider == kOneDrive) {
        return @"onedrive-2021";
    }
    else if(provider == kFilesAppUrlBookmark) {
        return @"lock";
    }
    else if(provider == kSFTP) {
        return @"cloud-sftp";
    }
    else if(provider == kWebDAV) {
        return @"cloud-webdav";
    }
    else {
        return @"SafeStorageProviderFactory::getIcon Unknown";
    }
}

@end

