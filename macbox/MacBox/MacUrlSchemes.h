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

StorageProvider storageProviderFromUrl(NSURL* url);
StorageProvider storageProviderFromUrlScheme(NSString* scheme);
NSString* schemeFromStorageProvider(StorageProvider storageProvider);

NS_ASSUME_NONNULL_END
