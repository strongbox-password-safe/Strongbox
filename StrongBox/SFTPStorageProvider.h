//
//  SFTPStorageProvider.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SFTPSessionConfiguration.h"
#import "SFTPProviderData.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFTPStorageProvider : NSObject<SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nullable) SFTPSessionConfiguration *unitTestingSessionConfiguration; 

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL privacyOptInRequired;

@property BOOL maintainSessionForListing;

- (SFTPProviderData*)getProviderDataFromMetaData:(METADATA_PTR)metaData;

@end

NS_ASSUME_NONNULL_END
