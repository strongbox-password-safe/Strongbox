//
//  ColoredStringHelper.h
//  Strongbox
//
//  Created by Mark on 02/03/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
    typedef UIFont* FONT_PTR;
    typedef UIColor* COLOR_PTR;
#else
    #import <Cocoa/Cocoa.h>
    typedef NSFont* FONT_PTR;
    typedef NSColor* COLOR_PTR;
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ColoredStringHelper : NSObject

+ (COLOR_PTR)getColorForCharacter:(NSString*)character darkMode:(BOOL)darkMode colorBlind:(BOOL)colorBlind;

+ (NSAttributedString *)getColorizedAttributedString:(NSString *)password
                                            colorize:(BOOL)colorize
                                            darkMode:(BOOL)darkMode
                                          colorBlind:(BOOL)colorBlind
                                                font:(FONT_PTR _Nullable)font;

@end

NS_ASSUME_NONNULL_END
