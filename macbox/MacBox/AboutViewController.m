//
//  AboutViewController.m
//  MacBox
//
//  Created by Strongbox on 07/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AboutViewController.h"
#import "Utils.h"
#import "Settings.h"
#import "ClipboardManager.h"
#import "DebugHelper.h"
#import "MacCustomizationManager.h"
#import "ProUpgradeIAPManager.h"
#import "ClickableTextField.h"
#import "AppDelegate.h"

@interface AboutViewController () <NSWindowDelegate>

@property BOOL hasLoaded;
@property (weak) IBOutlet NSTextField *labelAbout;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSTextField *labelLicense;
@property (weak) IBOutlet NSImageView *imageViewLicense;
@property (weak) IBOutlet ClickableTextField *labelChangeLicense;

@end

static AboutViewController* sharedInstance;

@implementation AboutViewController

+ (void)show {
    if ( sharedInstance == nil ) {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"AboutViewController" bundle:nil];
        NSWindowController* wc = [storyboard instantiateInitialController];
        sharedInstance = (AboutViewController*)wc.contentViewController;
    }
 
    [sharedInstance.view.window.windowController showWindow:self];
    [sharedInstance.view.window makeKeyAndOrderFront:self];
    [sharedInstance.view.window center];
}

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
    
    [self bindUi];
}

- (void)bindUi {
    [DebugHelper getAboutDebugString:^(NSString * _Nonnull debug) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.textView setString:debug];
        });
    }];
}

- (void)doInitialSetup {
    self.view.window.delegate = self;
    
    self.labelChangeLicense.onClick = ^{
        [self showUpgradeScreen];
    };

    [self bindVersionAndProStatus];
}

- (void)cancel:(id)sender { 
    [self.view.window close];
    sharedInstance = nil;
}

- (IBAction)onDone:(id)sender {
    [self.view.window close];
    sharedInstance = nil;
}

- (void)windowWillClose:(NSNotification *)notification {
    if ( notification.object == self.view.window && self == sharedInstance) {
        [self.view.window orderOut:self];
        sharedInstance = nil;
    }
}

- (IBAction)onCopy:(id)sender {
    NSString* debugInfo = [NSString stringWithString:self.textView.textStorage.string];
    
    [ClipboardManager.sharedInstance copyConcealedString:debugInfo];
}

- (void)bindVersionAndProStatus {
    NSString* fmt = NSLocalizedString(@"prefs_vc_app_version_info_none_pro_fmt", @"About Strongbox %@");
    NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
    self.view.window.title = about;
    self.labelAbout.stringValue = [Utils getAppVersion];
    
    
    
    self.labelLicense.textColor = NSColor.labelColor;
    BOOL linkToUpgradeScreen = NO;
    
    if ( MacCustomizationManager.isAProBundle ) {
        self.labelLicense.stringValue = NSLocalizedString(@"pro_status_lifetime_pro", @"Lifetime Pro");
    }
    else {
        if ( Settings.sharedInstance.isPro ) {
            if ( ProUpgradeIAPManager.sharedInstance.isLegacyLifetimeIAPPro ) { 
                self.labelLicense.stringValue = NSLocalizedString(@"pro_status_lifetime_pro_iap", @"Lifetime Pro (In-App Purchase)");
            }
            else if ( ProUpgradeIAPManager.sharedInstance.hasActiveYearlySubscription ){
                self.labelLicense.stringValue = NSLocalizedString(@"pro_status_yearly_pro", @"Pro (Yearly subscription)");
                linkToUpgradeScreen = YES;
            }
            else if ( ProUpgradeIAPManager.sharedInstance.hasActiveMonthlySubscription ) {
                self.labelLicense.stringValue = NSLocalizedString(@"pro_status_monthly_pro", @"Pro (Monthly subscription)");
                linkToUpgradeScreen = YES;
            }
            else {
                self.labelLicense.stringValue = NSLocalizedString(@"pro_badge_text", @"Pro"); 
            }
        }
        else if ( Settings.sharedInstance.daysInstalled > 60 ) {
            self.labelLicense.stringValue = NSLocalizedString(@"pro_status_unlicensed_please_upgrade", @"Unlicensed (Please Upgrade)");
            self.labelLicense.textColor = NSColor.systemRedColor;
            NSLocalizedString(@"generic_upgrade_ellipsis", @"Upgrade...");
            linkToUpgradeScreen = YES;
        }
        else {
            self.labelLicense.stringValue = NSLocalizedString(@"pro_status_unlicensed", @"Unlicensed");
            self.labelChangeLicense.stringValue = NSLocalizedString(@"generic_upgrade_ellipsis", @"Upgrade...");
            linkToUpgradeScreen = YES;
        }
    }
    
    self.labelChangeLicense.hidden = !linkToUpgradeScreen;
    
    
    
    BOOL licensed = Settings.sharedInstance.isPro;
    NSString* license = licensed ? @"person.fill.checkmark" : @"person.fill.xmark";
    
    NSImage* image = [NSImage imageWithSystemSymbolName:license  accessibilityDescription:nil];
    self.imageViewLicense.image = image;
    
    NSImageSymbolConfiguration* scaleConfig = [NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge];
    
    NSImageSymbolConfiguration* proConfig = [NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.systemGreenColor, NSColor.systemBlueColor]];
    NSImageSymbolConfiguration* noneProConfig = [NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.systemRedColor, NSColor.systemOrangeColor]];
    NSImageSymbolConfiguration* imageConfig = licensed ? proConfig : noneProConfig;
    
    self.imageViewLicense.symbolConfiguration = [scaleConfig configurationByApplyingConfiguration:imageConfig];
}

- (void)showUpgradeScreen {
    [NSApplication.sharedApplication sendAction:@selector(onUpgradeToFullVersion:) to:nil from:self];
    [self onDone:nil];
}

@end
