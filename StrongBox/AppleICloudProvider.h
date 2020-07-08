//
//  AppleICloudProvider.h
//  Strongbox
//
//  Created by Mark on 20/09/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "AppleICloudOrLocalSafeFile.h"
    
@interface AppleICloudProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
 suggestedFilename:(NSString*)suggestedFilename
      parentFolder:(NSObject *)parentFolder
    viewController:(UIViewController *)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline;

- (void)delete:(SafeMetaData*)safeMetaData
    completion:(void (^)(NSError *error))completion;

@end
