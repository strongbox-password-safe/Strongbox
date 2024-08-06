//
//  LargeTextViewController.m
//  Strongbox
//
//  Created by Mark on 23/10/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "LargeTextViewController.h"
#import "FontManager.h"
#import "ColoredStringHelper.h"
#import "AppPreferences.h"
#import "Utils.h"
#import "ClipboardManager.h"
#import "ColoredStringHelper.h"

#ifndef IS_APP_EXTENSION

#import "ISMessages/ISMessages.h"

#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface LargeTextViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *qrCodeImageView;
@property (weak, nonatomic) IBOutlet UILabel *labelSubtext;
@property (weak, nonatomic) IBOutlet UILabel *labelLargeTextCaption;
@property (weak, nonatomic) IBOutlet UIStackView *topStackView;
@property (weak, nonatomic) IBOutlet UIButton *buttonDismiss;
@property UIViewController* swiftUILargeTextView;

@end

@implementation LargeTextViewController

+ (instancetype)fromStoryboard {
    UIStoryboard* sb = [UIStoryboard storyboardWithName:@"LargeTextView" bundle:nil];
    return [sb instantiateInitialViewController];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.qrCodeImageView.hidden = YES;

    if ( !self.hideLargeTextGrid ) {
        [self loadSwiftUIView];
    }

    UITapGestureRecognizer *tapGestureRecognizerSubtext = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(subtextTapped)];
    tapGestureRecognizerSubtext.numberOfTapsRequired = 1;
    [self.labelSubtext addGestureRecognizer:tapGestureRecognizerSubtext];
    self.labelSubtext.userInteractionEnabled = YES;
    
    self.labelSubtext.text = self.subtext;
    self.labelSubtext.hidden = self.subtext.length == 0;
    self.labelLargeTextCaption.hidden = self.subtext.length == 0;
    self.labelLargeTextCaption.text = NSLocalizedString(@"generic_totp_secret", @"TOTP Secret");
    
    __weak LargeTextViewController* weakSelf = self;
    
    CGFloat width = self.qrCodeImageView.frame.size.width;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [weakSelf loadQrCode:width];
    });
}

- (void)loadSwiftUIView {
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    BOOL colorBlind = AppPreferences.sharedInstance.colorizeUseColorBlindPalette;
    
    self.swiftUILargeTextView = [SwiftUIViewFactory getLargeTextDisplayViewWithText:self.string
                                                                          font:FontManager.sharedInstance.easyReadFontForTotp
                                                                   colorMapper:^UIColor * _Nonnull(NSString * _Nonnull character) {
        return self.colorize ? [ColoredStringHelper getColorForCharacter:character darkMode:dark colorBlind:colorBlind] : UIColor.labelColor;
    } onTapped:^{
        [self labelTapped];
    }];

    [self addChildViewController:self.swiftUILargeTextView];
    self.swiftUILargeTextView.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.swiftUILargeTextView.view];
    [self.swiftUILargeTextView didMoveToParentViewController:self];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.swiftUILargeTextView.view.leftAnchor constraintEqualToAnchor:self.view.leftAnchor constant:20],
        [self.swiftUILargeTextView.view.rightAnchor constraintEqualToAnchor:self.view.rightAnchor constant:-20],
        [self.swiftUILargeTextView.view.topAnchor constraintEqualToAnchor:self.topStackView.bottomAnchor constant:20],
        [self.swiftUILargeTextView.view.bottomAnchor constraintGreaterThanOrEqualToAnchor:self.view.bottomAnchor constant:20],
    ]];
    
    [self.view layoutIfNeeded];
}

- (void)loadQrCode:(CGFloat)width {
    UIImage* img = [Utils getQrCode:self.string
                          pointSize:width];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.qrCodeImageView.image = img;
        
        self.qrCodeImageView.hidden = NO;
    });
}

- (IBAction)onDismiss:(id)sender {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)labelTapped {
    [self copyToClipboard:self.string];
}
    
- (void)subtextTapped {
    [self copyToClipboard:self.labelSubtext.text];
}

- (void)copyToClipboard:(NSString *)value {
    if (value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
    
#ifndef IS_APP_EXTENSION
    [ISMessages showCardAlertWithTitle:NSLocalizedString(@"generic_copied", @"Copied")
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
#endif
}

@end
