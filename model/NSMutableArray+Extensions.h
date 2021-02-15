//
//  NSMutableArray_Extensions.h
//  Strongbox
//
//  Created by Mark on 17/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableArray<ObjectType> (Extensions)

- (void)mutableFilter:(BOOL (^)(ObjectType obj))block;

@end

NS_ASSUME_NONNULL_END
