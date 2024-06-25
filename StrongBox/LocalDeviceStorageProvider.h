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



- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName
          data:(NSData *)data
       modDate:(NSDate*)modDate
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion;



- (BOOL)writeToDocumentsWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate;
- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data modDate:(NSDate*_Nullable)modDate;

- (NSURL *)getFileUrl:(METADATA_PTR )safeMetaData; 
- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename; 
- (BOOL)fileNameExistsInDocumentsFolder:(NSString*)filename; 
- (BOOL)isUsingSharedStorage:(METADATA_PTR )metadata;
- (void)delete:(METADATA_PTR )safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;

- (BOOL)renameFilename:(DatabasePreferences*)database filename:(NSString*)filename error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
