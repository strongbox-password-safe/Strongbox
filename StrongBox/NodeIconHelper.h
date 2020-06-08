//
//  NodeIconHelper.h
//  Strongbox
//
//  Created by Mark on 12/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Node.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeIconHelper : NSObject

+ (UIImage*)getIconForNode:(Node*)vm model:(Model*)model;

+ (UIImage *)getIconForNode:(BOOL)isGroup
             customIconUuid:(NSUUID*)customIconUuid
                     iconId:(NSNumber*)iconId
                   model:(Model *)model;

+ (UIColor*)folderTintColor;

+ (nullable UIImage*)getCustomIcon:(NSUUID*)uuid customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons;

+ (NSArray<UIImage*>*)getIconSet:(KeePassIconSet)iconSet;

@end

NS_ASSUME_NONNULL_END
