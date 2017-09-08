//
//  AppDelegate.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "DocumentController.h"
#import "Settings.h"
#import "UpgradeWindowController.h"
#import "Alerts.h"
#import "Utils.h"

//#define kIapFullVersionStoreId @"com.markmcguill.strongbox.test.consumable"
#define kIapFullVersionStoreId @"com.markmcguill.strongbox.mac.pro"

@interface AppDelegate ()

@property (nonatomic) BOOL applicationHasFinishedLaunching;
@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSArray<SKProduct *> *validProducts;
@property (strong, nonatomic) UpgradeWindowController *upgradeWindowController;

@end

@implementation AppDelegate

- (id)init {
    self = [super init];
    
    // Bizarre but to subclass NSDocumentController you must instantiate your document here, no need to assign
    // it anywhere it just picks it up by "magic" very strange...
    
    DocumentController *dc = [[DocumentController alloc] init];
    
    if(dc) {} // Unused Warning evasion...
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self removeUnwantedMenuItems];
    
    [self removeCopyDiagnosticDumpItem];
    
    if(![Settings sharedInstance].fullVersion) {
        [self getValidIapProducts];

        if([Settings sharedInstance].endFreeTrialDate == nil) {
            [self initializeFreeTrialAndShowWelcomeMessage];
        }
        else if(![Settings sharedInstance].freeTrial){
            [self randomlyShowUpgradeMessage];
        }
    }
    else {
        [self removeUpgradeMenuItem];
        
        [self randomlyPromptForAppStoreReview];
    }
    
    self.applicationHasFinishedLaunching = YES;
}

- (void)randomlyPromptForAppStoreReview {
    NSUInteger random = arc4random_uniform(100);
    
    // TODO: use iRate app?
    
    if(random % 5) {
        // TODO: Show
    }
}

- (void)initializeFreeTrialAndShowWelcomeMessage {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:2 toDate:[NSDate date] options:0];
    
    [Settings sharedInstance].endFreeTrialDate = date;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Alerts info:@"Welcome to StrongBox"
     informativeText:@"Hi and welcome to StrongBox!\n\n"
         @"I hope you'll really like the app, and find it useful. You can enjoy this fully featured Pro version of StrongBox for the next couple of months. "
         @"After that point, you will be transitioned to the regular version of StrongBox.\n\n"
         @"You can always find out more at any time by clicking 'Upgrade to Pro' in the StrongBox menu item.\n\n"
         @"Thanks!\n-Mark"
              window:[NSApplication sharedApplication].mainWindow 
          completion:nil];
    });
}

- (void)randomlyShowUpgradeMessage {
    NSUInteger random = arc4random_uniform(100);
    
    if(random % 3 == 0) {
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showUpgradeModal:3];
    }
}

- (void)getValidIapProducts {
    NSSet *productIdentifiers = [NSSet setWithObjects:kIapFullVersionStoreId, nil];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

-(void)productsRequest:(SKProductsRequest *)request
    didReceiveResponse:(SKProductsResponse *)response
{
    NSUInteger count = [response.products count];
    if (count > 0) {
        self.validProducts = response.products;
        for (SKProduct *validProduct in self.validProducts) {
            NSLog(@"%@", validProduct.productIdentifier);
            NSLog(@"%@", validProduct.localizedTitle);
            NSLog(@"%@", validProduct.localizedDescription);
            NSLog(@"%@", validProduct.price);
        }
    }
}

- (void)removeUnwantedMenuItems {
    // Remove Start Dictation and Emoji menu Items
    
    NSMenu* edit = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Edit"] submenu];
    
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"orderFrontCharacterPalette:")) {
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    }
    
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] action] == NSSelectorFromString(@"startDictation:")) {
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    }
    
    if ([[edit itemAtIndex: [edit numberOfItems] - 1] isSeparatorItem]) {
        [edit removeItemAtIndex: [edit numberOfItems] - 1];
    }
}

- (void)removeCopyDiagnosticDumpItem {
    NSMenu* safe = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"Safe"] submenu];
    if([[safe itemAtIndex:[safe numberOfItems] - 1] action] == NSSelectorFromString(@"onCopyDiagnosticDump:")) {
        [safe removeItemAtIndex:[safe numberOfItems] - 1];
    }
}

- (void)removeUpgradeMenuItem {
    NSMenu* strongBox = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle: @"StrongBox"] submenu];
    if([[strongBox itemAtIndex:2] action] == NSSelectorFromString(@"onUpgradeToFullVersion:")) {
        [strongBox removeItemAtIndex:2];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    if(!self.applicationHasFinishedLaunching) {
        // Get the recent documents
        NSDocumentController *controller =
        [NSDocumentController sharedDocumentController];
        NSArray *documents = [controller recentDocumentURLs];
        
        // If there is a recent document, try to open it.
        if ([documents count] > 0)
        {
            [controller openDocumentWithContentsOfURL:[documents objectAtIndex:0] display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) { ; }];

            return NO;
        }
    }
    
    return YES;
}

- (IBAction)onUpgradeToFullVersion:(id)sender {
    [self showUpgradeModal:0];
}

- (void)showUpgradeModal:(NSInteger)delay {
    SKProduct* product = [_validProducts objectAtIndex:0];
    
    if([UpgradeWindowController run:product cancelDelay:delay]) {
        [[Settings sharedInstance] setFullVersion:YES];
        [self removeUpgradeMenuItem];
    };
}

- (IBAction)onEmailSupport:(id)sender {
    NSString* subject = [NSString stringWithFormat:@"StrongBox %@ Support", [Utils getAppVersion]];
    NSString* emailBody = @"Hi,\n\nI'm having some trouble with StrongBox.\n\n<Please include as much detail as possible here including screenshots where appropriate.>";
    NSString* toAddress = @"support@strongboxsafe.com";
    
    NSSharingService* emailService = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
    emailService.recipients = @[toAddress];
    emailService.subject = subject;
    
    if ([emailService canPerformWithItems:@[emailBody]]) {
        [emailService performWithItems:@[emailBody]];
    } else {
        NSString *encodedSubject = [NSString stringWithFormat:@"SUBJECT=%@", [subject stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSString *encodedBody = [NSString stringWithFormat:@"BODY=%@", [emailBody stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSString *encodedTo = [toAddress stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *encodedURLString = [NSString stringWithFormat:@"mailto:%@?%@&%@", encodedTo, encodedSubject, encodedBody];
        NSURL *mailtoURL = [NSURL URLWithString:encodedURLString];
        
        if(![[NSWorkspace sharedWorkspace] openURL:mailtoURL]) {
            [Alerts info:@"Email Unavailable"
         informativeText:@"StrongBox could not initialize an email for you, perhaps because it is not configured.\n\n"
                        @"Please send an email to support@strongboxsafe.com with details of your issue."
                  window:[NSApplication sharedApplication].mainWindow
              completion:nil];
        }
    }
}

//    [[Settings sharedInstance] setFullVersion:NO];
//[[Settings sharedInstance] setEndFreeTrialDate:nil];
//    NSCalendar *cal = [NSCalendar currentCalendar];
//    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:-10 toDate:[NSDate date] options:0];
//    [[Settings sharedInstance] setEndFreeTrialDate:date];
//

@end
