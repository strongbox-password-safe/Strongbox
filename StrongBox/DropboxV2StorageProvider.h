//
//  DropboxV2StorageProvider.h
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeStorageProvider.h"

@interface DropboxV2StorageProvider : NSObject <SafeStorageProvider>

+ (instancetype)sharedInstance;

@property (strong, nonatomic, readonly) NSString *displayName;
@property (strong, nonatomic, readonly) NSString *icon;
@property (nonatomic, readonly) StorageProvider storageId;
@property (nonatomic, readonly) BOOL cloudBased;
@property (nonatomic, readonly) BOOL providesIcons;
@property (nonatomic, readonly) BOOL browsable;

@end
