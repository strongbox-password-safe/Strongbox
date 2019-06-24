//
//  DuressDummyStorageProvider.h
//  Strongbox
//
//  Created by Mark on 16/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DuressDummyStorageProvider : NSObject<SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL cloudBased;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;

- (SafeMetaData *_Nullable)getSafeMetaData:(NSString *)nickName filename:(NSString*)filename fileIdentifier:(NSString*)fileIdentifier;

@property (nonatomic, nonnull, readonly) DatabaseModel* database;

@end

NS_ASSUME_NONNULL_END
