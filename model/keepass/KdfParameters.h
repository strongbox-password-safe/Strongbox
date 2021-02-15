//
//  KdfParameters.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VariantObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface KdfParameters : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithParameters:(NSDictionary<NSString*, VariantObject*>*)parameters NS_DESIGNATED_INITIALIZER;

@property (nullable, readonly, nonatomic) NSUUID* uuid;
@property (readonly, nonatomic) NSDictionary<NSString*, VariantObject*>* parameters;

@end

NS_ASSUME_NONNULL_END
