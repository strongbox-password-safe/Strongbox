//
//  BackupItem.h
//  Strongbox-iOS
//
//  Created by Mark on 26/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackupItem : NSObject

+ (instancetype)withUrl:(NSURL*)url date:(NSDate*)date fileSize:(NSNumber*)fileSize;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUrl:(NSURL*)url date:(NSDate*)date fileSize:(NSNumber*)fileSize NS_DESIGNATED_INITIALIZER;

@property (readonly) NSURL* url;
@property (readonly) NSDate* date;
@property (readonly) NSNumber *fileSize;

@end

NS_ASSUME_NONNULL_END
