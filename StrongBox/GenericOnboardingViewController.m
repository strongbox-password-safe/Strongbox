//
//  GenericOnboardingViewController.m
//  Strongbox
//
//  Created by Strongbox on 18/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "GenericOnboardingViewController.h"
#import "FontManager.h"

@interface GenericOnboardingViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *labelTitle;
@property (weak, nonatomic) IBOutlet UILabel *labelMessage;

@property (weak, nonatomic) IBOutlet RoundedBlueButton *labelButton2;
@property (weak, nonatomic) IBOutlet RoundedBlueButton *labelButton3;

@property (weak, nonatomic) IBOutlet UIButton *buttonDismiss;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageWidthConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *button1Width;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *button2Width;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *button3Width;

@end

@implementation GenericOnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.buttonDismiss setTitle:NSLocalizedString(@"generic_dismiss", @"Dismiss") forState:UIControlStateNormal];
    if ( self.hideDismiss ) {
        self.buttonDismiss.hidden = YES;
    }
    
    self.imageView.image = self.image;
    
    if (@available(iOS 17.0, *)) {
        if ( self.symbolEffect ) {
            [self.imageView addSymbolEffect:self.symbolEffect
                                    options:[NSSymbolEffectOptions optionsWithRepeating]
                                   animated:YES];
        }
    }
    
    self.labelTitle.text = self.header;
    self.labelMessage.text = self.message;
    [self.labelButton1 setTitle:self.button1 forState:UIControlStateNormal];
    
    if ( self.button2.length ) {
        [self.labelButton2 setTitle:self.button2 forState:UIControlStateNormal];
    }
    else {
        self.labelButton2.hidden = YES;
    }

    if ( self.button3.length ) {
        [self.labelButton3 setTitle:self.button3 forState:UIControlStateNormal];
    }
    else {
        self.labelButton3.hidden = YES;
    }
    
    self.imageWidthConstraint.constant = self.imageSize == 0 ? 128 : self.imageSize;
    self.imageHeightConstraint.constant = self.imageSize == 0 ? 128 : self.imageSize;
    
    if ( self.button1Color ) {
        self.labelButton1.backgroundColor = self.button1Color;
    }
    if ( self.button2Color ) {
        self.labelButton2.backgroundColor = self.button2Color;
    }
    if ( self.button3Color ) {
        self.labelButton3.backgroundColor = self.button3Color;
    }
    
    if ( self.buttonWidth != nil ) {
        self.button1Width.constant = self.buttonWidth.floatValue;
        self.button2Width.constant = self.buttonWidth.floatValue;
        self.button3Width.constant = self.buttonWidth.floatValue;
    }
}

- (IBAction)onButton1:(id)sender {
    self.onButtonClicked(1, self, self.onDone);
}

- (IBAction)onButton2:(id)sender {
    self.onButtonClicked(2, self, self.onDone);
}

- (IBAction)onButton3:(id)sender {
    self.onButtonClicked(3, self, self.onDone);
}

- (IBAction)onDismiss:(id)sender {
    self.onButtonClicked(0, self, self.onDone);
}

@end
