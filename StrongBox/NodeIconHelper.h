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
+ (NSArray<UIImage*>*)iconSet;

@end

NS_ASSUME_NONNULL_END
