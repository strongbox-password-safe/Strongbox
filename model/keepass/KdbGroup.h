//
//  KdbGroup.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KdbGroup : NSObject

@property (nonatomic) uint32_t groupId;
@property (nonatomic) NSString* name;
@property (nonatomic) NSDate* creation;
@property (nonatomic) NSDate* modification;
@property (nonatomic) NSDate* lastAccess;
@property (nonatomic) NSDate* expiry;
@property (nonatomic) NSNumber* imageId;
@property (nonatomic) uint16_t level;
@property (nonatomic) uint32_t flags;


@end

NS_ASSUME_NONNULL_END
