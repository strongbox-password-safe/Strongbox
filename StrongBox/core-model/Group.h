//
//  Group.h
//  StrongBox
//
//  Created by Mark McGuill on 27/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Group : NSObject

-(Group*)init:(NSString*)fullPath;

@property (readonly, nonatomic) NSString* fullPath;
@property (readonly, nonatomic) NSString* fullPathDisplayString;
@property (readonly, nonatomic) NSString* suffixDisplayString;
@property (readonly, nonatomic) NSString* pathPrefixDisplayString;
@property (nonatomic, readonly) BOOL isRootGroup;


-(NSArray*)splitGroup;
-(BOOL)isSubgroupOf:(Group*)parentGroup;
-(BOOL)isSameGroupAs:(Group*)existing;
-(BOOL)isDirectChildOf:(Group*)testGroup;

-(Group*)getImmediateChildGroupWithParentGroup:(Group*)parentGroup;
-(Group*)createChildGroupWithUITitle:(NSString*)title;
-(Group*)getParentGroup;

@end
