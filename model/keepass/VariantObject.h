//
//  VariantObject.h
//  Strongbox-iOS
//
//  Created by Mark on 05/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

static const uint8_t kVariantTypeUint32 = 0x04;
static const uint8_t kVariantTypeUint64 = 0x05;
static const uint8_t kVariantTypeInt32 = 0x0C;
static const uint8_t kVariantTypeInt64 = 0x0D;
static const uint8_t kVariantTypeBool = 0x08;
static const uint8_t kVariantTypeString = 0x18;
static const uint8_t kVariantTypeByteArray = 0x42;

NS_ASSUME_NONNULL_BEGIN

@interface VariantObject : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithType:(uint8_t)type theObject:(NSObject*)theObject NS_DESIGNATED_INITIALIZER;

@property uint8_t type;
@property NSObject* theObject;

@end

NS_ASSUME_NONNULL_END
