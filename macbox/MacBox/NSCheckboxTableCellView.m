//
//  NSCheckboxTableCellView.m
//  Strongbox
//
//  Created by Mark on 03/07/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "NSCheckboxTableCellView.h"

@implementation NSCheckboxTableCellView

- (IBAction)onCheckboxClicked:(id)sender {
    if(self.onClicked) {
        self.onClicked(self.checkbox.state == NSControlStateValueOn);
    }
}

@end
