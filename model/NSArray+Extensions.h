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

- (NSArray<ObjectType> *)filter:(BOOL (^)(ObjectType obj))block;
- (NSArray*)map:(id (^)(ObjectType obj, NSUInteger idx))block;
- (nullable ObjectType)firstOrDefault:(BOOL (^)(ObjectType obj))block;
- (BOOL)anyMatch:(BOOL (^)(ObjectType obj))block;
- (BOOL)allMatch:(BOOL (^)(ObjectType obj))block;

- (NSArray *)flatMap:(NSArray* (^)(ObjectType obj, NSUInteger idx))block;

@end

NS_ASSUME_NONNULL_END
