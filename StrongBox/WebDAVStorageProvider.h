//
//  WebDAVStorageProvider.h
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "DAVKit.h"
#import "WebDAVSessionConfiguration.h"
#import "WebDAVProviderData.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVStorageProvider : NSObject<SafeStorageProvider, DAVRequestDelegate>

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL privacyOptInRequired;

@property WebDAVSessionConfiguration* explicitConnection;
@property BOOL maintainSessionForListing;

- (WebDAVProviderData*)getProviderDataFromMetaData:(METADATA_PTR)metaData;
- (WebDAVSessionConfiguration*_Nullable)getConnectionFromDatabase:(METADATA_PTR)metaData;

- (void)testConnection:(WebDAVSessionConfiguration*)connection viewController:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(NSError* error))completion;

@end

NS_ASSUME_NONNULL_END
