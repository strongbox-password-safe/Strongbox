//
//  WebDAVStorageProvider.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "DAVKit.h"
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVStorageProvider : NSObject<SafeStorageProvider, DAVRequestDelegate>

+ (instancetype)sharedInstance;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL allowOfflineCache;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;

@property WebDAVSessionConfiguration* unitTestSessionConfiguration;
@property BOOL maintainSessionForListings;

@end

NS_ASSUME_NONNULL_END
