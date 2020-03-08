//
//  LargeTextViewController.m
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "LargeTextViewController.h"
#import "FontManager.h"
#import "ColoredStringHelper.h"
#import "Settings.h"

@interface LargeTextViewController ()

@property (weak, nonatomic) IBOutlet UILabel *labelLargeText;

@end

@implementation LargeTextViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped)];
    
    tapGestureRecognizer.numberOfTapsRequired = 1;
    
    [self.labelLargeText addGestureRecognizer:tapGestureRecognizer];
    self.labelLargeText.userInteractionEnabled = YES;

    if (!self.colorize) {
        self.labelLargeText.font = FontManager.sharedInstance.easyReadFontForTotp;
        self.labelLargeText.text = self.string;
    }
    else {
        BOOL dark = NO;
        if (@available(iOS 12.0, *)) {
            dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
        }
        BOOL colorBlind = Settings.sharedInstance.colorizeUseColorBlindPalette;
    
        self.labelLargeText.attributedText = [ColoredStringHelper getColorizedAttributedString:self.string
                                                                                      colorize:YES
                                                                                      darkMode:dark
                                                                                    colorBlind:colorBlind font:FontManager.sharedInstance.easyReadFontForTotp];
        
    }
}

- (void)labelTapped {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

@end
