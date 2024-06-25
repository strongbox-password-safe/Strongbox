//
//  AboutViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 30/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AboutViewController.h"
#import "DebugHelper.h"
#import "ClipboardManager.h"
#import "Alerts.h"
#import "AppPreferences.h"
#import "Utils.h"
#import "ProUpgradeIAPManager.h"
#import "CustomizationManager.h"

@interface AboutViewController ()

@property (weak, nonatomic) IBOutlet UITextView *debugTextView;
@property (weak, nonatomic) IBOutlet UITextView *aboutTextView;
@property (weak, nonatomic) IBOutlet UIButton *upgradeOptions;

@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if([[AppPreferences sharedInstance] isPro]) {
        NSString* about = [NSString stringWithFormat:
                       NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@"), [Utils getAppVersion]];

        self.navigationItem.title = about;
    }

    self.upgradeOptions.hidden = CustomizationManager.isAProBundle || ProUpgradeIAPManager.sharedInstance.isLegacyLifetimeIAPPro; 
    
    self.debugTextView.layer.cornerRadius = 2.0f;
    self.debugTextView.layer.borderColor = [UIColor.secondaryLabelColor CGColor];

    self.debugTextView.layer.borderWidth = 0.5f;

    self.aboutTextView.layer.cornerRadius = 2.0f;
    self.aboutTextView.layer.borderColor = [UIColor.secondaryLabelColor CGColor];

    self.aboutTextView.layer.borderWidth = 0.5f;

    [DebugHelper getAboutDebugString:^(NSString * _Nonnull debug) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.debugTextView.text = debug;
        });
    }];
    
    NSURL* rtfPath = [NSBundle.mainBundle URLForResource:@"" withExtension:@"rtf"];
    
    if(rtfPath) {
        NSError* error;
        NSMutableAttributedString* attributedStringWithRtf = [[NSMutableAttributedString alloc] initWithURL:rtfPath
                                                                                                    options:@{ NSDocumentTypeDocumentOption :  NSRTFTextDocumentType }
                                                                                         documentAttributes:nil
                                                                                                      error:&error];
        UIColor *color = UIColor.labelColor;
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color };
        [attributedStringWithRtf addAttributes:attrs range:NSMakeRange(0, attributedStringWithRtf.length)];
        
        self.aboutTextView.attributedText = error ? [[NSAttributedString alloc] initWithString:error.description] : attributedStringWithRtf;
    }
}

- (IBAction)onCopy:(id)sender {
    [DebugHelper getAboutDebugString:^(NSString * _Nonnull debug) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ClipboardManager.sharedInstance copyStringWithNoExpiration:debug];
            
            [Alerts info:self title:@"Done" message:@"Debug Info copied to clipboard"];
        });
    }];
}

- (IBAction)onUpgradeOptions:(id)sender {
    [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
}

@end
