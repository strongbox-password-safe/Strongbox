//
//  CustomPasswordTextField.h
//  Strongbox
//
//  Created by Mark on 15/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomPasswordTextField : NSTextField

@property (copy)void (^onBecomesFirstResponder)(void);

@end

NS_ASSUME_NONNULL_END
