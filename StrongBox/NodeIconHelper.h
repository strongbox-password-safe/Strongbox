//
//  NodeIconHelper.h
//  Strongbox
//
//  Created by Mark on 12/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "NodeIcon.h"
#import "KeePassIconSet.h"
#import "DatabaseFormat.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeIconHelper : NSObject

+ (NSArray<IMAGE_TYPE_PTR>*)getIconSet:(KeePassIconSet)iconSet;

+ (IMAGE_TYPE_PTR)getIconForNode:(Node *)vm predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format;
+ (IMAGE_TYPE_PTR)getIconForNode:(Node *)vm predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format large:(BOOL)large;

+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon*)icon;
+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon*)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet;
+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon*)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format;
+ (IMAGE_TYPE_PTR)getNodeIcon:(NodeIcon *)icon predefinedIconSet:(KeePassIconSet)predefinedIconSet format:(DatabaseFormat)format isGroup:(BOOL)isGroup;

@end

NS_ASSUME_NONNULL_END
