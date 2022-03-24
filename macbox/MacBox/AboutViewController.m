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

@interface AboutViewController () <NSWindowDelegate>

@property BOOL hasLoaded;
@property (weak) IBOutlet NSTextField *labelAbout;
@property (unsafe_unretained) IBOutlet NSTextView *textView;

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
    NSString* debug = [DebugHelper getAboutDebugString];
    [self.textView setString:debug];
}

- (void)doInitialSetup {
    self.view.window.delegate = self;
    
    NSString* fmt = Settings.sharedInstance.isAProBundle ? NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@") : NSLocalizedString(@"prefs_vc_app_version_info_none_pro_fmt", @"About Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
    
    self.view.window.title = about;
    self.labelAbout.stringValue = about;
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

@end
