//
//  OneDriveStorageProvider.h
//  Strongbox-iOS
//
//  Created by Mark on 25/07/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

@interface OneDriveStorageProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline;

- (void)signout:(void (^)(NSError *error))completion;
- (BOOL)isSignedIn;
    
@end
