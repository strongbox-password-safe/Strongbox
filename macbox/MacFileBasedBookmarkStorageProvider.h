//
//  MacFileBasedBookmarkStorageProvider.h
//  MacBox
//
//  Created by Strongbox on 22/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacFileBasedBookmarkStorageProvider : NSObject<SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL privacyOptInRequired;

@end

NS_ASSUME_NONNULL_END
