//
//  NSArray+Extensions.h
//  Strongbox-iOS
//
//  Created by Mark on 03/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<ObjectType> (Extensions)

- (NSArray*)map:(id (^)(ObjectType obj, NSUInteger idx))block;

@end

NS_ASSUME_NONNULL_END
