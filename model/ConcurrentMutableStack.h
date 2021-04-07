//
//  ConcurrentMutableStack.h
//  Strongbox
//
//  Created by Strongbox on 31/03/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConcurrentMutableStack<ObjectType> : NSObject

+ (instancetype)mutableStack;

- (void)push:(ObjectType)anObject;
- (ObjectType)pop;
- (ObjectType)popAndClear;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
