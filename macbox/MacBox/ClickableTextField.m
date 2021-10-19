//
//  ClickableTextField.m
//  MacBox
//
//  Created by Strongbox on 20/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ClickableTextField.h"

@implementation ClickableTextField

//- (void)mouseDown:(NSEvent *)event {
//    NSLog(@"mouseDown");
//}

- (void)mouseUp:(NSEvent *)event {
    
    if(self.onClick) {
        self.onClick();
    }
}

@end
