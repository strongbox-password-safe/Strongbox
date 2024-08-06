//
//  ClickableSecureTextField.m
//  Strongbox
//
//  Created by Mark on 06/03/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ClickableSecureTextField.h"

@implementation ClickableSecureTextField

- (void)mouseDown:(NSEvent *)event {
//    slog(@"mouseDown"); 
}

- (void)mouseUp:(NSEvent *)event {

    
    if(self.onClick) {
        self.onClick();
    }
}

@end
