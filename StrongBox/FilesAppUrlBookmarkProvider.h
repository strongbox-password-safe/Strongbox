//
//  FilesAppUrlBookmarkProvider.h
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilesAppUrlBookmarkProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL privacyOptInRequired;

- (NSString* _Nullable)getJsonFileIdentifier:(NSData*)bookmark;
- (DatabasePreferences *)getDatabasePreferences:(NSString *)nickName fileName:(NSString*)fileName providerData:(NSObject *)providerData;

@end

NS_ASSUME_NONNULL_END
