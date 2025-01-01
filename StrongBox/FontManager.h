//
//  FontManager.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DatabasePreferences.h"

NS_ASSUME_NONNULL_BEGIN

@interface FontManager : NSObject

@property (class, readonly) FontManager* shared;

+ (instancetype)sharedInstance;

#if !TARGET_OS_WATCH

@property (readonly) UIFont* easyReadFont;
@property (readonly) UIFont* easyReadBoldFont;
@property (readonly) UIFont* easyReadFontForTotp;
@property (readonly) UIFont* easyReadFontForLargeTextView;

#endif

@property (readonly) UIFont* regularFont;

@property (readonly) UIFont* title1Font;
@property (readonly) UIFont* title2Font;
@property (readonly) UIFont* title3Font;

@property (readonly) UIFont* headlineFont;
@property (readonly) UIFont* subheadlineFont;
@property (readonly) UIFont* headlineItalicFont;
@property (readonly) UIFont* italicFont;
@property (readonly) UIFont* caption1Font;
@property (readonly) UIFont* caption2Font;

@end

NS_ASSUME_NONNULL_END
