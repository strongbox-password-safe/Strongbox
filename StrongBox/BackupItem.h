//
//  BackupItem.h
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupItem : NSObject

+ (instancetype)withUrl:(NSURL*)url backupCreatedDate:(NSDate*)backupCreatedDate modDate:(NSDate*)modDate fileSize:(NSNumber*)fileSize;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUrl:(NSURL*)url backupCreatedDate:(NSDate*)backupCreatedDate modDate:(NSDate*)modDate fileSize:(NSNumber*)fileSize NS_DESIGNATED_INITIALIZER;

@property (readonly) NSURL* url;
@property (readonly) NSDate* backupCreatedDate;
@property (readonly) NSDate* modDate;
@property (readonly) NSNumber *fileSize;

@end

NS_ASSUME_NONNULL_END
