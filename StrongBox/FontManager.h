//
//  FontManager.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface FontManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly) UIFont* easyReadFont;
@property (readonly) UIFont* easyReadBoldFont;
@property (readonly) UIFont* easyReadFontForTotp;
@property (readonly) UIFont* easyReadFontForLargeTextView;
@property (readonly) UIFont* regularFont;
@property (readonly) UIFont* title2Font;
@property (readonly) UIFont* italicFont;
@property (readonly) UIFont* caption1Font;

@end

NS_ASSUME_NONNULL_END
