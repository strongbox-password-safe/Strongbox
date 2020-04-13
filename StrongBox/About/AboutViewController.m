//
//  AboutViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "AboutViewController.h"
#import "DebugHelper.h"
#import "ClipboardManager.h"
#import "Alerts.h"
#import "Settings.h"
#import "Utils.h"
#import "ProUpgradeIAPManager.h"

@interface AboutViewController ()

@property (weak, nonatomic) IBOutlet UITextView *debugTextView;
@property (weak, nonatomic) IBOutlet UITextView *aboutTextView;
@property (weak, nonatomic) IBOutlet UIButton *upgradeOptions;

@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if([[Settings sharedInstance] isPro]) {
        NSString* about = [NSString stringWithFormat:
                       NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@"), [Utils getAppVersion]];

        self.navigationItem.title = about;
    }

    self.upgradeOptions.hidden = ProUpgradeIAPManager.isProFamilyEdition || ProUpgradeIAPManager.sharedInstance.hasPurchasedLifeTime; // If we know user is lifetime don't show option to change license
    
    self.debugTextView.layer.cornerRadius = 2.0f;
    if (@available(iOS 13.0, *)) {
        self.debugTextView.layer.borderColor = [UIColor.secondaryLabelColor CGColor];
    } else {
        self.debugTextView.layer.borderColor = [UIColor.darkGrayColor CGColor];
    }
    self.debugTextView.layer.borderWidth = 0.5f;

    self.aboutTextView.layer.cornerRadius = 2.0f;
    if (@available(iOS 13.0, *)) {
        self.aboutTextView.layer.borderColor = [UIColor.secondaryLabelColor CGColor];
    } else {
        self.debugTextView.layer.borderColor = [UIColor.darkGrayColor CGColor];
    }
    self.aboutTextView.layer.borderWidth = 0.5f;

    self.debugTextView.text = [DebugHelper getAboutDebugString];
    
    NSURL* rtfPath = [NSBundle.mainBundle URLForResource:@"" withExtension:@"rtf"];
    
    if(rtfPath) {
        NSError* error;
        NSMutableAttributedString* attributedStringWithRtf = [[NSMutableAttributedString alloc] initWithURL:rtfPath
                                                                                                    options:@{ NSDocumentTypeDocumentOption :  NSRTFTextDocumentType }
                                                                                         documentAttributes:nil
                                                                                                      error:&error];
        UIColor *color;
        if (@available(iOS 13.0, *)) {
            color = UIColor.labelColor;
            NSDictionary *attrs = @{ NSForegroundColorAttributeName : color };
            [attributedStringWithRtf addAttributes:attrs range:NSMakeRange(0, attributedStringWithRtf.length)];
        }
        
        self.aboutTextView.attributedText = error ? [[NSAttributedString alloc] initWithString:error.description] : attributedStringWithRtf;
    }
}

- (IBAction)onCopy:(id)sender {
    [UIPasteboard.generalPasteboard setString:[DebugHelper getAboutDebugString]];
    [Alerts info:self title:@"Done" message:@"Debug Info copied to clipboard"];
}

- (IBAction)onDone:(id)sender {
    self.onDone();
}

- (IBAction)onUpgradeOptions:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

@end
