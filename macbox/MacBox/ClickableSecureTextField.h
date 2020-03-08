//
//  ClickableSecureTextField.h
//  Strongbox
//
//  Created by Mark on 06/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClickableSecureTextField : NSSecureTextField

@property (copy)void (^onClick)(void);

@end

NS_ASSUME_NONNULL_END
