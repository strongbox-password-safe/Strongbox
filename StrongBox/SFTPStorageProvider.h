//
//  SFTPStorageProvider.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SFTPSessionConfiguration.h"
#import "SFTPProviderData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFTPStorageProvider : NSObject<SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nullable) SFTPSessionConfiguration *unitTestingSessionConfiguration; // Keep Session across Listing/Create operations, otherwise use the specified SafeMetaData config 

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline;

@property BOOL maintainSessionForListing;

- (SFTPProviderData*)getProviderDataFromMetaData:(SafeMetaData*)metaData;

@end

NS_ASSUME_NONNULL_END
