//
//  SelectedStorageParameters.h
//  Strongbox-iOS
//
//  Created by Mark on 01/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (unsigned int, DatabaseStorageMethod) {
    kStorageMethodUserCancelled,
    kStorageMethodErrorOccurred,
    kStorageMethodFilesAppUrl,
    kStorageMethodManualUrlDownloadedData,
    kStorageMethodNativeStorageProvider
};

@interface SelectedStorageParameters : NSObject

+ (instancetype)userCancelled;
+ (instancetype)error:(NSError*)error withProvider:(id<SafeStorageProvider>)provider;
+ (instancetype)parametersForFilesApp:(NSURL*)url;
+ (instancetype)parametersForManualDownload:(NSData*)data;
+ (instancetype)parametersForNativeProviderExisting:(id<SafeStorageProvider>)provider file:(StorageBrowserItem* _Nullable)file;
+ (instancetype)parametersForNativeProviderCreate:(id<SafeStorageProvider>)provider folder:(NSObject* _Nullable)folder;

@property DatabaseStorageMethod method;
@property (nullable) NSURL* url;
@property (nullable) NSData* data;
@property (nullable) id<SafeStorageProvider> provider;
@property (nullable) StorageBrowserItem *file;
@property (nullable) NSObject *parentFolder;
@property (nullable) NSError* error;
@property BOOL createMode;

@end

NS_ASSUME_NONNULL_END
