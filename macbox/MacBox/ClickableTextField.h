//
//  ClickableTextField.h
//  MacBox
//
//  Created by Strongbox on 20/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClickableTextField : NSTextField

@property (copy, nullable) void (^onClick)(void);

@end

NS_ASSUME_NONNULL_END
