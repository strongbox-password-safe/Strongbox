//
//  BackupsManager.h
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BackupItem.h"
#import "CommonDatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN


@interface BackupsManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)writeBackup:(NSURL*)snapshot metadata:(METADATA_PTR)metadata;
- (void)deleteBackup:(BackupItem*)item;
- (void)deleteAllBackups:(METADATA_PTR)metadata;

- (NSArray<BackupItem*>*)getAvailableBackups:(METADATA_PTR _Nullable)metadata all:(BOOL)all;

@end

NS_ASSUME_NONNULL_END
