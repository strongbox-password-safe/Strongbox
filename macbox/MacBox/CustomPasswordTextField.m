//
//  CustomPasswordTextField.m
//  Strongbox
//
//  Created by Mark on 15/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CustomPasswordTextField.h"

@implementation CustomPasswordTextField

- (BOOL)becomeFirstResponder {
    self.onBecomesFirstResponder();
    
    return [super becomeFirstResponder];
}

@end
