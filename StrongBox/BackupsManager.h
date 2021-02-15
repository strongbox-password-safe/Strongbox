//
//  BackupsManager.h
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SafeMetaData.h"
#import "BackupItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface BackupsManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)writeBackup:(NSURL*)snapshot metadata:(SafeMetaData*)metadata;
- (void)deleteBackup:(BackupItem*)item;
- (void)deleteAllBackups:(SafeMetaData*)metadata;

- (NSArray<BackupItem*>*)getAvailableBackups:(SafeMetaData*)metadata;

@end

NS_ASSUME_NONNULL_END
