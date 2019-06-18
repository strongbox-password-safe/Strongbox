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

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL cloudBased;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsableNew;
@property (nonatomic, readonly) BOOL browsableExisting;
@property (nonatomic, readonly) BOOL rootFolderOnly;

// Used on creation of brand new safe via standard UI
- (void)    create:(NSString *)nickName
         extension:(NSString *)extension
              data:(NSData *)data
      parentFolder:(NSObject * _Nullable)parentFolder
    viewController:(UIViewController * _Nullable)viewController
        completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

// Used during importation when we have a good idea of what the filename should be - try to maintain it if possible

- (void)        create:(NSString *)nickName
             extension:(NSString *)extension
                  data:(NSData *)data
     suggestedFilename:(NSString*)suggestedFilename
            completion:(void (^)(SafeMetaData *metadata, NSError *error))completion;

// Used during importation - we may just want to update the underlying local file (seems to be a common usage pattern)
- (BOOL)writeToDefaultStorageWithFilename:(NSString*)filename overwrite:(BOOL)overwrite data:(NSData *)data;

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^ _Nullable)(NSError *_Nullable error))completion;

- (void)startMonitoringDocumentsDirectory;

- (NSURL *)getFileUrl:(SafeMetaData *)safeMetaData; // used by iCloud Migration
- (BOOL)fileNameExistsInDefaultStorage:(NSString*)filename; // used by Import to see if we should update


- (void)migrateLocalDatabasesToNewSystem;

@end

NS_ASSUME_NONNULL_END
