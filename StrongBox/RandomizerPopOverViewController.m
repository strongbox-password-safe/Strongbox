//
//  RandomizerPopOverViewController.m
//  Strongbox
//
//  Created by Strongbox on 25/05/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "RandomizerPopOverViewController.h"
#import "PasswordMaker.h"
#import "AppPreferences.h"
#import "ColoredStringHelper.h"
#import "FontManager.h"
#import "ClipboardManager.h"
#import "Strongbox-Swift.h"

@interface RandomizerPopOverViewController ()

@property (weak, nonatomic) IBOutlet UIButton *button1;
@property (weak, nonatomic) IBOutlet UIButton *button2;
@property (weak, nonatomic) IBOutlet UIButton *button3;
@property (weak, nonatomic) IBOutlet UIButton *button4;
@property (weak, nonatomic) IBOutlet UIButton *button5;
@property (weak, nonatomic) IBOutlet UIButton *barButtonConfig;
@property (weak, nonatomic) IBOutlet UIButton *barButtonRefresh;

@end

@implementation RandomizerPopOverViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.barButtonConfig setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];
    [self.barButtonRefresh setImage:[UIImage systemImageNamed:@"arrow.triangle.2.circlepath"] forState:UIControlStateNormal];

    [self makeButtonLabelAdjustForLength:self.button1];
    [self makeButtonLabelAdjustForLength:self.button2];
    [self makeButtonLabelAdjustForLength:self.button3];
    [self makeButtonLabelAdjustForLength:self.button4];
    [self makeButtonLabelAdjustForLength:self.button5];
    
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.preferredContentSize = [self.view systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
}

- (void)makeButtonLabelAdjustForLength:(UIButton*)button {
    button.titleLabel.adjustsFontSizeToFitWidth = YES;
    button.titleLabel.numberOfLines = 1;
    
    button.titleLabel.minimumScaleFactor = 0.70f;
}

- (IBAction)onRefresh:(id)sender {
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];

    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    [self refresh];
}

- (void)refresh {
    NSString* example1 = [PasswordMaker.sharedInstance generateBasicForConfig:AppPreferences.sharedInstance.passwordGenerationConfig];
    NSString* example2 = [PasswordMaker.sharedInstance
                           generateDicewareForConfig:AppPreferences.sharedInstance.passwordGenerationConfig];
    
    NSString* example3 = [PasswordMaker.sharedInstance generateUsername];
    NSString* example4 = [PasswordMaker.sharedInstance generateRandomWord];
    NSString* example5 = NSUUID.UUID.UUIDString;


    [UIView performWithoutAnimation:^{
        NSAttributedString* attrExample1 = [self getAttributedString:example1];
        [self.button1 setAttributedTitle:attrExample1 forState:UIControlStateNormal];
        [self.button1 layoutIfNeeded];
        
        NSAttributedString* attrExample2 = [self getAttributedString:example2];
        [self.button2 setAttributedTitle:attrExample2 forState:UIControlStateNormal];
        [self.button2 layoutIfNeeded];

        NSAttributedString* attrExample3 = [self getAttributedString:example3];
        [self.button3 setAttributedTitle:attrExample3 forState:UIControlStateNormal];
        [self.button3 layoutIfNeeded];

        NSAttributedString* attrExample4 = [self getAttributedString:example4];
        [self.button4 setAttributedTitle:attrExample4 forState:UIControlStateNormal];
        [self.button4 layoutIfNeeded];

        NSAttributedString* attrExample5 = [self getAttributedString:example5];
        [self.button5 setAttributedTitle:attrExample5 forState:UIControlStateNormal];
        [self.button5 layoutIfNeeded];
    }];
}

- (NSAttributedString*)getAttributedString:(NSString*)str {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;

    return [ColoredStringHelper getColorizedAttributedString:str
                                                    colorize:YES
                                                    darkMode:dark
                                                  colorBlind:colorBlind
                                                        font:FontManager.sharedInstance.easyReadFont];
    
}

- (IBAction)onCopyText:(id)sender {
    UIButton* button = sender;
    NSString* text= button.titleLabel.text;
    
    [ClipboardManager.sharedInstance copyStringWithNoExpiration:text];
    
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    [StrongboxToastMessages showToastWithTitle:NSLocalizedString(@"generic_copied", @"Copied") body:@"" category:ToastMessageCategoryInfo icon:ToastIconInfo];
}


@end
