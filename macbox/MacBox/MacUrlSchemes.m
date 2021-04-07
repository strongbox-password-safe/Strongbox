//
//  MacUrlSchemes.m
//  MacBox
//
//  Created by Strongbox on 09/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MacUrlSchemes.h"

NSString* const kStrongboxSFTPUrlScheme = @"sftp";
NSString* const kStrongboxWebDAVUrlScheme = @"webdav";
NSString* const kStrongboxFileUrlScheme = @"file";
NSString* const kStrongboxSyncManagedFileUrlScheme = @"sb-sync-managed-file";

StorageProvider storageProviderFromUrl(NSURL* url) {
    return url ? storageProviderFromUrlScheme(url.scheme) : kMacFile;
}

StorageProvider storageProviderFromUrlScheme(NSString* scheme) {
    if ( [scheme isEqualToString:kStrongboxSFTPUrlScheme] ) {
        return kSFTP;
    }
    else if ( [scheme isEqualToString:kStrongboxWebDAVUrlScheme] ) {
        return kWebDAV;
    }
    
    return kMacFile;
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











