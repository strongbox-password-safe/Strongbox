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
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NodeIconHelper : NSObject

+ (UIImage*)getIconForNode:(Node*)vm database:(DatabaseModel*)database;
+ (UIImage *)getIconForNode:(BOOL)isGroup
             customIconUuid:(NSUUID*)customIconUuid
                     iconId:(NSNumber*)iconId
                   database:(DatabaseModel *)database;

+ (UIColor*)folderTintColor;
+ (NSArray<UIImage*>*)iconSet;
+ (nullable UIImage*)getCustomIcon:(NSUUID*)uuid customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons;

@end

NS_ASSUME_NONNULL_END
