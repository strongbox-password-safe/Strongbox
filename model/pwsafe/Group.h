//
//  Group.h
//  StrongBox
//
//  Created by Mark McGuill on 27/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

@interface Group : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initAsRootGroup;
- (instancetype)initWithPathComponents:(NSArray<NSString*> *)pathComponents NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithEscapedPathString:(NSString *)escapedPathString NS_DESIGNATED_INITIALIZER;

@property (readonly, nonatomic, copy) NSArray<NSString *> *pathComponents;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) BOOL isRootGroup;
@property (nonatomic, readonly) NSString *escapedPathString;
@property (NS_NONATOMIC_IOSONLY, getter = getParentGroup, readonly, strong) Group *parentGroup;

- (BOOL)isSubgroupOf:(Group *)parentGroup;
- (Group *)getDirectAncestorOfParent:(Group *)parentGroup;

- (Group *)createChildGroupWithTitle:(NSString *)title;

@end
