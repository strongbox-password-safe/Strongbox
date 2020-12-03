//
//  LocalDeviceStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalDeviceStorageProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL immediatelyOfferCacheIfOffline;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;



- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject * _Nullable)parentFolder
    viewController:(UIViewController * _Nullable)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *_Nullable error))completion;



- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
       modDate:(NSDate*)modDate
suggestedFilename:(NSString*)suggestedFilename
    completion:(void (^)(SafeMetaData *metadata, NSError *_Nullable error))completion;


- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data;

- (NSURL *)getFileUrl:(SafeMetaData *)safeMetaData; 
- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename; 
- (BOOL)isUsingSharedStorage:(SafeMetaData*)metadata;
- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
