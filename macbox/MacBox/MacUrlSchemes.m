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
    
    return kLocalDevice;
}

NSString* schemeFromStorageProvider(StorageProvider storageProvider) {
    if ( storageProvider == kSFTP ) {
        return kStrongboxSFTPUrlScheme;
    }
    else if ( storageProvider == kWebDAV ) {
        return kStrongboxWebDAVUrlScheme;
    }
    
    return kStrongboxFileUrlScheme;
}
