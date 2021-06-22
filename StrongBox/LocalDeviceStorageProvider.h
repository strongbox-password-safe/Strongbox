//
//  LocalDeviceStorageProvider.h
//  StrongBox
//
//  Created by Mark on 19/11/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalDeviceStorageProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;
@property (nonatomic, readonly) BOOL defaultForImmediatelyOfferOfflineCache;
@property (nonatomic, readonly) BOOL supportsConcurrentRequests;
@property (nonatomic, readonly) BOOL privacyOptInRequired;



- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject * _Nullable)parentFolder
    viewController:(VIEW_CONTROLLER_PTR  _Nullable)viewController
        completion:(void (^)(METADATA_PTR metadata, NSError *_Nullable error))completion;



- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
       modDate:(NSDate*)modDate
suggestedFilename:(NSString*)suggestedFilename
    completion:(void (^)(METADATA_PTR metadata, NSError *_Nullable error))completion;


- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate;

- (NSURL *)getFileUrl:(METADATA_PTR )safeMetaData; 
- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename; 
- (BOOL)isUsingSharedStorage:(METADATA_PTR )metadata;
- (void)delete:(METADATA_PTR )safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
