//
//  QuickViewConfig.h
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface QuickViewConfig : NSObject

+ (instancetype)title:(NSString*)title subtitle:(NSString*)subtitle image:(UIImage*)image searchTerm:(NSString*)searchTerm;
+ (instancetype)title:(NSString*)title subtitle:(NSString*)subtitle image:(UIImage*)image searchTerm:(NSString*)searchTerm imageTint:(UIColor*_Nullable)imageTint;

@property NSString* title;
@property NSString* subtitle;
@property UIImage* image;
@property NSString* searchTerm;
@property (nullable) UIColor* imageTint;

@end

NS_ASSUME_NONNULL_END
