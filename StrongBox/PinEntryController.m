//
//  PinEntryController.m
//  Strongbox
//
//  Created by Mark on 11/01/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PinEntryController.h"

@interface PinEntryController ()

@property UIBarButtonItem* okButton;

@end

@implementation PinEntryController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    
    numberToolbar.barStyle = UIBarStyleDefault;
    
    self.okButton = [[UIBarButtonItem alloc]initWithTitle:@"OK" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)];
    
    self.labelSubtitle.text = self.info.length ? self.info : @"Please Enter Your PIN";
    self.labelWarning.text = self.warning;
    
    if(self.showFallbackOption) {
        numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                                [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                [[UIBarButtonItem alloc]initWithTitle:@"Master Credentials..." style:UIBarButtonItemStylePlain target:self action:@selector(fallback)],
                                [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                self.okButton];
    }
    else {
        numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                                [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                self.okButton];
    }
    
    [numberToolbar sizeToFit];
    self.textFieldPin.inputAccessoryView = numberToolbar;

    [self validatePin];
}


- (void)validatePin {
    NSCharacterSet *numbersOnly = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSCharacterSet *characterSetFromTextField = [NSCharacterSet characterSetWithCharactersInString:self.textFieldPin.text];
    
    self.okButton.enabled = self.textFieldPin.text.length > 3 && [numbersOnly isSupersetOfSet:characterSetFromTextField];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.textFieldPin becomeFirstResponder];
}

-(void)cancelNumberPad{
    [self.textFieldPin resignFirstResponder];
    self.onDone(kCancel, nil);
}

-(void)fallback{
    [self.textFieldPin resignFirstResponder];
    self.onDone(kFallback, nil);
}

-(void)doneWithNumberPad{
    [self.textFieldPin resignFirstResponder];
    self.onDone(kOk, self.textFieldPin.text);
}

- (IBAction)onEditPin:(id)sender {
    [self validatePin];
}

@end
