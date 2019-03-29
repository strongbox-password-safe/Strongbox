//
//  CustomFieldTableCellView.m
//  Strongbox
//
//  Created by Mark on 28/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "CustomFieldTableCellView.h"

@interface CustomFieldTableCellView ()

@property (weak) IBOutlet NSButton *buttonShowHide;
@property (weak) IBOutlet NSTextField *labelText;

@property NSString* val;
@property BOOL prot;
@property BOOL valueIsHidden;

@end

@implementation CustomFieldTableCellView

- (NSString *)value {
    return self.val;
}

- (void)setValue:(NSString *)value {
    self.val = value;
    [self updateUI];
}

- (BOOL)protected {
    return self.prot;
}

- (void)setProtected:(BOOL)protected {
    self.prot = protected;
    [self updateUI];
}

- (BOOL)valueHidden {
    return self.valueIsHidden;
}

- (void)setValueHidden:(BOOL)valueHidden {
    self.valueIsHidden = valueHidden;
    [self updateUI];
}

- (IBAction)onShowHide:(id)sender {
    self.valueHidden = !self.valueHidden;
    [self updateUI];
}

- (void)updateUI {
    if(self.valueHidden) {
        self.labelText.stringValue = @"*******************";
        [self.buttonShowHide setImage:[NSImage imageNamed:@"show"]];
    }
    else {
        self.labelText.stringValue = self.val;
        [self.buttonShowHide setImage:[NSImage imageNamed:@"hide"]];
    }
    
    self.buttonShowHide.hidden = !self.protected;
}

@end
