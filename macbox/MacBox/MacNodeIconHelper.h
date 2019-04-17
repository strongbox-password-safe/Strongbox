//
//  NodeIconHelper.h
//  Strongbox
//
//  Created by Mark on 12/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MacNodeIconHelper : NSObject

+ (NSImage * )getIconForNode:(ViewModel*)model vm:(Node *)vm large:(BOOL)large;
+ (NSImage* _Nullable)getCustomIcon:(NSUUID*)uuid customIcons:(NSDictionary<NSUUID*, NSData*>*)customIcons;

@end

NS_ASSUME_NONNULL_END
