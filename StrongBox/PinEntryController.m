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
@property UIToolbar* numberToolbar;

@end

@implementation PinEntryController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //[self setupAccessoryViewToolbar];

    self.buttonMasterFallback.hidden = !self.showFallbackOption;
    self.labelSubtitle.text = self.info.length ? self.info : @"Please Enter Your PIN";
    self.labelWarning.text = self.warning;
    [self validatePin];
}

- (void)setupAccessoryViewToolbar {
    self.numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    self.numberToolbar.barStyle = UIBarStyleDefault;

    self.okButton = [[UIBarButtonItem alloc]initWithTitle:@"OK" style:UIBarButtonItemStyleDone target:self action:@selector(doneWithNumberPad)];

    if(self.showFallbackOption) {
        self.numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                                [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                [[UIBarButtonItem alloc]initWithTitle:@"Master Credentials..." style:UIBarButtonItemStylePlain target:self action:@selector(fallback)],
                                [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                self.okButton];
    }
    else {
        self.numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:@"Cancel" style:UIBarButtonItemStylePlain target:self action:@selector(cancelNumberPad)],
                                [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                                self.okButton];
    }

    [self.numberToolbar sizeToFit];
    self.textFieldPin.inputAccessoryView = self.numberToolbar;
}

- (void)validatePin {
    NSCharacterSet *numbersOnly = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    NSCharacterSet *characterSetFromTextField = [NSCharacterSet characterSetWithCharactersInString:self.textFieldPin.text];
    
    self.okButton.enabled = self.textFieldPin.text.length > 3 && [numbersOnly isSupersetOfSet:characterSetFromTextField];
    self.buttonOK.enabled = self.textFieldPin.text.length > 3 && [numbersOnly isSupersetOfSet:characterSetFromTextField];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.textFieldPin becomeFirstResponder];
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

- (IBAction)onOK:(id)sender {
    [self.textFieldPin resignFirstResponder];
    self.onDone(kOk, self.textFieldPin.text);
}

- (IBAction)onCancel:(id)sender {
    [self.textFieldPin resignFirstResponder];
    self.onDone(kCancel, nil);
}

- (IBAction)onUseMasterCredentials:(id)sender {
    [self.textFieldPin resignFirstResponder];
    self.onDone(kFallback, nil);
}

- (IBAction)onEditPin:(id)sender {
    [self validatePin];
}

@end
