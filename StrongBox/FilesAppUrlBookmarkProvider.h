//
//  FilesAppUrlBookmarkProvider.h
//  Strongbox
//
//  Created by Mark on 05/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
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
@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline;

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName fileName:(NSString*)fileName providerData:(NSObject *)providerData;

- (BOOL)autoFillBookMarkIsSet:(SafeMetaData*)metadata;
- (SafeMetaData*)setAutoFillBookmark:(NSData*)bookmark metadata:(SafeMetaData*)metadata;

@end

NS_ASSUME_NONNULL_END
