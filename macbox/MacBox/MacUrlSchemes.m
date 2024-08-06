//
//  MacUrlSchemes.m
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacUrlSchemes.h"
#import "StrongboxMacFilesManager.h"

NSString* const kStrongboxSFTPUrlScheme = @"sftp";
NSString* const kStrongboxWebDAVUrlScheme = @"webdav";
NSString* const kStrongboxOneDriveUrlScheme = @"onedrive";
NSString* const kStrongboxGoogleDriveUrlScheme = @"googledrive";
NSString* const kStrongboxDropboxUrlScheme = @"dropbox";
NSString* const kStrongboxFileUrlScheme = @"file";
NSString* const kStrongboxSyncManagedFileUrlScheme = @"sb-sync-managed-file";

NSString* const kStrongboxWiFiSyncUrlScheme = @"wifi";
NSString* const kStrongboxCloudUrlScheme = @"strongbox-cloud";

StorageProvider storageProviderFromUrl(NSURL* url) {
    return url ? storageProviderFromUrlScheme(url.scheme) : kLocalDevice;
}

StorageProvider storageProviderFromUrlScheme(NSString* scheme) {
    if ( [scheme isEqualToString:kStrongboxSFTPUrlScheme] ) {
        return kSFTP;
    }
    else if ( [scheme isEqualToString:kStrongboxWebDAVUrlScheme] ) {
        return kWebDAV;
    }
    else if ( [scheme isEqualToString:kStrongboxOneDriveUrlScheme] ) {
        return kOneDrive;
    }
    else if ( [scheme isEqualToString:kStrongboxGoogleDriveUrlScheme ] ) {
        return kGoogleDrive;
    }
    else if ( [scheme isEqualToString:kStrongboxDropboxUrlScheme ] ) {
        return kDropbox;
    }
    else if ( [scheme isEqualToString:kStrongboxWiFiSyncUrlScheme ] ) {
        return kWiFiSync;
    }
    else if ( [scheme isEqualToString:kStrongboxCloudUrlScheme ] ) {
        return kCloudKit;
    }
    
    return kLocalDevice;
}

NSURL* fileUrlFromManagedUrl(NSURL* managedUrl) {
    if ( [managedUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        NSURLComponents* components =  [NSURLComponents componentsWithURL:managedUrl resolvingAgainstBaseURL:NO];
        components.scheme = kStrongboxFileUrlScheme;
        return components.URL;
    }

    return managedUrl;
}

NSURL* managedUrlFromFileUrl(NSURL* fileUrl) {
    if ( [fileUrl.scheme isEqualToString:kStrongboxFileUrlScheme] ) {
        NSURLComponents* components =  [NSURLComponents componentsWithURL:fileUrl resolvingAgainstBaseURL:NO];
        components.scheme = kStrongboxSyncManagedFileUrlScheme;
        return components.URL;
    }
    
    return fileUrl;
}

NSString* getPathRelativeToUserHome(NSString* path) {
    NSString* userHome = StrongboxFilesManager.sharedInstance.userHomePath;
    
    if ( userHome && path.length > userHome.length ) {
        path = [path stringByReplacingOccurrencesOfString:userHome withString:@"~" options:kNilOptions range:NSMakeRange(0, userHome.length)];
    }
    
    return path;
}

NSString* getFriendlyICloudPath(NSString* path) {
    NSURL* iCloudRoot = StrongboxFilesManager.sharedInstance.iCloudRootURL;
    NSURL* iCloudDriveRoot = StrongboxFilesManager.sharedInstance.iCloudDriveRootURL;

    
    
    if ( iCloudRoot && path.length > iCloudRoot.path.length && [[path substringToIndex:iCloudRoot.path.length] isEqualToString:iCloudRoot.path]) {
        return [NSString stringWithFormat:@"%@ (%@)", path.lastPathComponent, NSLocalizedString(@"databases_vc_database_location_suffix_database_is_in_official_icloud_strongbox_folder", @"Strongbox iCloud")];
    }
    
    
    
    if ( iCloudDriveRoot && path.length > iCloudDriveRoot.path.length && [[path substringToIndex:iCloudDriveRoot.path.length] isEqualToString:iCloudDriveRoot.path]) {
        NSArray *iCloudDriveDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:iCloudDriveRoot.path];
        NSArray *pathDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:path];

        if ( pathDisplayComponents.count > iCloudDriveDisplayComponents.count ) {
            NSArray* relative = [pathDisplayComponents subarrayWithRange:NSMakeRange(iCloudDriveDisplayComponents.count, pathDisplayComponents.count - iCloudDriveDisplayComponents.count)];
            
            if ( relative.count > 1 ) {
                NSString* niceICloudDriveName = relative.firstObject;
                NSArray* pathWithiniCloudDrive = [relative subarrayWithRange:NSMakeRange(1, relative.count-1)];
                NSString* strPathWithiniCloudDrive = [pathWithiniCloudDrive componentsJoinedByString:@"/"];
                return [NSString stringWithFormat:@"%@ (%@)", strPathWithiniCloudDrive, niceICloudDriveName];
            }
        }
    }

    return getPathRelativeToUserHome(path);
}
