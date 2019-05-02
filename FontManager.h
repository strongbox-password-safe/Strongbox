//
//  FontManager.h
//  test-new-ui
//
//  Created by Mark on 18/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FontManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly) UIFont* easyReadFont;
@property (readonly) UIFont* easyReadFontForTotp;
@property (readonly) UIFont* regularFont;
@property (readonly) UIFont* configuredValueFont;

@end

NS_ASSUME_NONNULL_END
