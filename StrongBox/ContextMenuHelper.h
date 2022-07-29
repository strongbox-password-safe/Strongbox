//
//  ContextMenuHelper.h
//  Strongbox
//
//  Created by Strongbox on 05/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContextMenuHelper : NSObject

+ (UIAction*)getItem:(NSString*)title image:(UIImage*)image handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0));

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0));

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*)systemImage enabled:(BOOL)enabled handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0));

+ (UIAction*)getItem:(NSString*)title systemImage:(NSString*)systemImage enabled:(BOOL)enabled checked:(BOOL)checked handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0));

+ (UIAction*)getDestructiveItem:(NSString*)title systemImage:(NSString*)systemImage handler:(UIActionHandler)handler API_AVAILABLE(ios(13.0));






@end

NS_ASSUME_NONNULL_END
