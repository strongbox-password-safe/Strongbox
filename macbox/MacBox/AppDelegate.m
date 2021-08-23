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
#import "MacAlerts.h"
#import "Utils.h"
#import "Strongbox.h"
#import "PreferencesWindowController.h"
#import "DatabasesManagerVC.h"
#import "BiometricIdHelper.h"
#import "ViewController.h"
#import "DatabasesManager.h"
#import "SafeStorageProviderFactory.h"
#import "AboutViewController.h"
#import "FileManager.h"
#import "ClipboardManager.h"
#import "DebugHelper.h"
#import "MacUrlSchemes.h"
#import "Shortcut.h"
#import "NodeDetailsViewController.h"
#import "Document.h"
#import "WebDAVStorageProvider.h"
#import "SFTPStorageProvider.h"
#import "WebDAVConnections.h"
#import "SFTPConnections.h"
#import "SFTPConnectionsManager.h"



#define kIapFullVersionStoreId @"com.markmcguill.strongbox.mac.pro"



static NSString* const kIapProId =  @"com.markmcguill.strongbox.pro";
static NSString* const kMonthly =  @"com.strongbox.markmcguill.upgrade.pro.monthly";
static NSString* const kYearly =  @"com.strongbox.markmcguill.upgrade.pro.yearly";
static NSString* const kIapFreeTrial =  @"com.markmcguill.strongbox.ios.iap.freetrial";

static NSString * const kProFamilyEditionBundleId = @"com.markmcguill.strongbox.mac.pro";
static NSString * const kBundledFreemiumBundleId = @"com.markmcguill.strongbox"; 



NSString* const kStrongboxPasteboardName = @"Strongbox-Pasteboard";
NSString* const kDragAndDropInternalUti = @"com.markmcguill.strongbox.drag.and.drop.internal.uti";
NSString* const kDragAndDropExternalUti = @"com.markmcguill.strongbox.drag.and.drop.external.uti";

static const NSInteger kTopLevelMenuItemTagStrongbox = 1110;
static const NSInteger kTopLevelMenuItemTagFile = 1111;




@interface AppDelegate () 

@property (strong) IBOutlet NSMenu *systemTraymenu;
@property NSStatusItem* statusItem;

@property (nonatomic, strong) SKProductsRequest *productsRequest;
@property (nonatomic, strong) NSArray<SKProduct *> *validProducts;
@property (strong, nonatomic) UpgradeWindowController *upgradeWindowController;
@property (strong, nonatomic) dispatch_block_t autoLockWorkBlock;
@property NSTimer* clipboardChangeWatcher;
@property NSInteger currentClipboardVersion;

@end

@implementation AppDelegate

- (id)init {
    self = [super init];
    
    
    
    
    DocumentController *dc = [[DocumentController alloc] init];
    
    if(dc) {} 
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self performMigrations];
    
    [self cleanupWorkingDirectories];

    
    
    
    
    

    [self applyCustomizations];
            
    [self showHideSystemStatusBarIcon];
    
    [self installGlobalHotKeys];
            
    

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DocumentController* dc = NSDocumentController.sharedDocumentController;
        
        [dc onAppStartup];
        
        [self listenToEvents];
    });
}

- (void)customizeForNonPro {
    if(!Settings.sharedInstance.fullVersion) {
        [self getValidIapProducts];

        if(![Settings sharedInstance].freeTrial) {
            

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(180 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^ {
                [self randomlyShowUpgradeMessage];
            });
        }
    
        if([Settings sharedInstance].endFreeTrialDate == nil) {
            [self initializeFreeTrialAndShowWelcomeMessage];
        }
    }
}

- (void)listenToEvents {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowDidMiniaturizeOrClose:)
                                                 name:NSWindowDidMiniaturizeNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowDidMiniaturizeOrClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:nil];





    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPreferencesChanged:)
                                                 name:kPreferencesChangedNotification
                                               object:nil];
}



- (void)onWindowDidMiniaturizeOrClose:(NSNotification*)notification {
    if ( ![notification.object isMemberOfClass:NSWindow.class] ) { 
        NSLog(@"Ignoring non-window based notification");
        return;
    }

    NSWindow* win = notification.object;
    
    BOOL interesting = win.contentViewController &&
    ( [win.contentViewController isKindOfClass:ViewController.class] ||
      [win.contentViewController isKindOfClass:NodeDetailsViewController.class]);



    NSLog(@"onWindowDidMiniaturizeOrClose: [%@-%@-%@]", win, win.title, win.contentViewController.className);

    if ( !interesting ) {
        NSLog(@"Ignoring non View Controller based notification");
        return;
    }















    NSArray* docs = DocumentController.sharedDocumentController.documents;
    NSArray* mainWindows = [docs map:^id _Nonnull(id  _Nonnull obj, NSUInteger idx) {
        Document* doc = obj;
        NSWindowController* wc = (NSWindowController*)doc.windowControllers.firstObject;
        return wc.window;
    }];

    for(NSWindow* win in mainWindows) {
        NSLog(@"Full List: [%@-%@-%@]", win, win.title, win.contentViewController.className);
    }

    BOOL allMiniaturized = [mainWindows allMatch:^BOOL(NSWindow * _Nonnull obj) {
        return obj.miniaturized;
    }];
    
    if ( allMiniaturized ) {
        NSLog(@"allMiniaturized.");
        
        if ( Settings.sharedInstance.showSystemTrayIcon && Settings.sharedInstance.hideDockIconOnAllMinimized ) {
            [self showHideDockIcon:NO];
        }
    }
    else {
        NSArray *a = [mainWindows filter:^BOOL(NSWindow * _Nonnull obj) {
            return !obj.miniaturized;
        }];

        for(NSWindow* win in a) {
            NSLog(@"Not Miniaturized: [%@-%@-%@]", win, win.title, win.contentViewController.className);
        }
    }
}

- (void)showHideDockIcon:(BOOL)show {
    

    if ( show ) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    else {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        
        
        



    }
}



- (void)performMigrations {
    [self migrateToSyncManager]; 
    [self performConnectionMigrations]; 
}

- (void)performConnectionMigrations {
    if ( !Settings.sharedInstance.migratedConnections ) {
        int wcount = 0;
        int scount = 0;
        
        NSArray* databases = DatabasesManager.sharedInstance.snapshot;
        
        for ( DatabaseMetadata *database in  databases ) {
            if ( database.storageProvider == kWebDAV ) {
                WebDAVProviderData* pd = [WebDAVStorageProvider.sharedInstance getProviderDataFromMetaData:database];
                if (  pd.sessionConfiguration ) {
                    if ( pd.sessionConfiguration.name.length == 0 ) {
                        pd.sessionConfiguration.name = [NSString stringWithFormat:@"%@ %@", pd.sessionConfiguration.host, @(++wcount)];
                    }
                    [WebDAVConnections.sharedInstance addOrUpdate:pd.sessionConfiguration];
                    
                    DatabaseMetadata* newDatabase = [WebDAVStorageProvider.sharedInstance getSafeMetaData:database.nickName providerData:pd];
                                        
                    [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                        metadata.fileUrl = newDatabase.fileUrl;
                        metadata.storageInfo = newDatabase.storageInfo;
                    }];
                    
                    NSLog(@"Migrated WebDAV Connection");
                }
            }
            else if ( database.storageProvider == kSFTP ) {                
                SFTPProviderData* pd = [SFTPStorageProvider.sharedInstance getProviderDataFromMetaData:database];
                SFTPSessionConfiguration* connection = pd.sFtpConfiguration;
                
                if ( connection ) {
                    if ( connection.name.length == 0 ) {
                        connection.name = [NSString stringWithFormat:@"%@ %@", connection.host, @(++scount)];
                    }

                    [SFTPConnections.sharedInstance addOrUpdate:connection];
                    
                    DatabaseMetadata* newDatabase = [SFTPStorageProvider.sharedInstance getSafeMetaData:database.nickName providerData:pd];
                    
                    [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                        metadata.fileUrl = newDatabase.fileUrl;
                        metadata.storageInfo = newDatabase.storageInfo;
                    }];

                    NSLog(@"Migrated SFTP Connection = [%@] - %@", pd.connectionIdentifier, connection.identifier);
                }
            }
        }
        
        Settings.sharedInstance.migratedConnections = YES;
    }
}

- (void)migrateToSyncManager {
    if ( !Settings.sharedInstance.hasMigratedToSyncManager ) {
         Settings.sharedInstance.hasMigratedToSyncManager = YES;
        [self migrateLocalDatabasesToSyncManager];
    }
}

- (void)migrateLocalDatabasesToSyncManager {
    NSLog(@"migrateLocalDatabasesToSyncManager");

    NSArray<DatabaseMetadata*>* databases = DatabasesManager.sharedInstance.snapshot;
    for (DatabaseMetadata* database in databases) {
        if (database.storageProvider == kMacFile ) {
            NSURLComponents* components = [NSURLComponents componentsWithURL:database.fileUrl resolvingAgainstBaseURL:NO];
            components.scheme = kStrongboxSyncManagedFileUrlScheme;
            
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.fileUrl = components.URL;
            }];
            
            NSLog(@"Converted [%@] Database to [%@]", database.nickName, database.fileUrl);
        }
    }
}

- (void)cleanupWorkingDirectories {
    [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
    [FileManager.sharedInstance deleteAllTmpWorkingFiles];
}

- (void)applyCustomizations {
    if([self isProFamilyEdition]) {
        NSLog(@"Initial launch of Pro/Family Edition... setting Pro");
        [Settings.sharedInstance setFullVersion:YES];
    }
    
    [self customizeMenu];
    
    [self customizeForNonPro];
}

- (BOOL)isProFamilyEdition {
    NSString* bundleId = [Utils getAppBundleId];
    return [bundleId isEqualToString:kProFamilyEditionBundleId];
}

- (BOOL)isBundledFreemiumEdition {
    NSString* bundleId = [Utils getAppBundleId];
    return [bundleId isEqualToString:kBundledFreemiumBundleId];
}

- (void)showHideSystemStatusBarIcon {   
    if(Settings.sharedInstance.showSystemTrayIcon) {
        if(!self.statusItem) {
            NSImage* statusImage = [NSImage imageNamed:@"AppIcon-glyph"];
            statusImage.size = NSMakeSize(18.0, 18.0);
            self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            self.statusItem.image = statusImage;
            self.statusItem.highlightMode = YES;
            self.statusItem.enabled = YES;
            self.statusItem.menu = self.systemTraymenu;
            self.statusItem.toolTip = @"Strongbox";
        }
    }
    else {
        if(self.statusItem) {
            [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
            self.statusItem = nil;
        }
    }
}

- (IBAction)onSystemTrayQuitStrongbox:  (id)sender {
    [NSApplication.sharedApplication terminate:nil];
}

- (IBAction)onSystemTrayShow:(id)sender {
    [self showAndActivateStrongbox];
}

- (void)showAndActivateStrongbox {
    NSLog(@"showAndActivateStrongbox");
    
    [NSApp arrangeInFront:nil];
    [NSApplication.sharedApplication.mainWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    for ( NSWindow* win in [NSApp windows] ) { 
        if([win isMiniaturized]) {
            [win deminiaturize:self];
        }
    }

    [self showHideDockIcon:YES];
    
    DocumentController* dc = NSDocumentController.sharedDocumentController;
    [dc performEmptyLaunchTasksIfNecessary];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if(Settings.sharedInstance.clearClipboardEnabled) {
        [self clearClipboardWhereAppropriate];
    }
    
    
    
    [self clearAppCustomClipboard];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if(self.autoLockWorkBlock) {
        dispatch_block_cancel(self.autoLockWorkBlock);
        self.autoLockWorkBlock = nil;
    }
}

- (ViewController*)getActiveViewController {
    if(NSApplication.sharedApplication.keyWindow) {
        NSWindow *window = NSApplication.sharedApplication.keyWindow;
        NSDocument* doc = [NSDocumentController.sharedDocumentController documentForWindow:window];
        
        if(doc && doc.windowControllers.count) {
            NSWindowController* windowController = [doc.windowControllers firstObject];
            NSViewController* vc = windowController.contentViewController;
            
            if(vc && [vc isKindOfClass:ViewController.class]) {
                return (ViewController*)vc;
            }
        }
    }
    
    return nil;
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    NSInteger timeout = [[Settings sharedInstance] autoLockTimeoutSeconds];
    
    if(timeout != 0) {
        self.autoLockWorkBlock = dispatch_block_create(0, ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kAutoLockTime object:nil];
            self.autoLockWorkBlock = nil;
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), self.autoLockWorkBlock);
    }
}

- (void)initializeFreeTrialAndShowWelcomeMessage {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:3 toDate:[NSDate date] options:0];
    
    [Settings sharedInstance].endFreeTrialDate = date;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString* loc = NSLocalizedString(@"mac_welcome_to_strongbox_title", @"Welcome to Strongbox");
        NSString* loc2 = NSLocalizedString(@"mac_welcome_to_strongbox_message", @"Hi and welcome to Strongbox!\n\n"
                                @"I hope you'll really like the app, and find it useful. You can enjoy this fully featured Pro version of Strongbox for the next three months. "
                                @"After that point, you will be transitioned to the regular version of Strongbox.\n\n"
                                @"You can always find out more at any time by tapping 'Upgrade to Pro' in the Strongbox menu item.\n\n"
                                @"Thanks!\n-Mark");

        [MacAlerts info:loc
     informativeText:loc2
              window:[NSApplication sharedApplication].mainWindow 
          completion:nil];
    });
}

- (void)randomlyShowUpgradeMessage {
    NSUInteger random = arc4random_uniform(100);
    
    NSUInteger showPercentage = 15;
    if(random < showPercentage) {
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showUpgradeModal:1];
    }
}



- (void)getValidIapProducts {
    NSLog(@"getValidIapProducts");
    
    NSSet *productIdentifiers = [self isBundledFreemiumEdition] ? [NSSet setWithArray:@[kIapProId, kYearly, kMonthly, kIapFreeTrial]] : [NSSet setWithArray:@[kIapFullVersionStoreId]];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appStoreProductRequestCompleted:response.products error:nil];
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self appStoreProductRequestCompleted:nil error:error];
    });
}

- (void)appStoreProductRequestCompleted:(NSArray<SKProduct *> *)products error:(NSError*)error {
    NSLog(@"products = [%@]", products);
    
    if(products) {
        NSUInteger count = [products count];
        if (count > 0) {
            self.validProducts = products;
            for (SKProduct *validProduct in self.validProducts) {
                NSLog(@"%@", validProduct.productIdentifier);
                NSLog(@"%@", validProduct.localizedTitle);
                NSLog(@"%@", validProduct.localizedDescription);
                NSLog(@"%@", validProduct.price);
            }
        }
    }
    else {
        
        
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];
    
    if (theAction == @selector(onUpgradeToFullVersion:)) {
        return self.validProducts != nil;
    }
    
    if (theAction == @selector(onFloatOnTopToggle:)) {
        NSMenuItem* item = (NSMenuItem*) anItem;
        [item setState:Settings.sharedInstance.floatOnTop ? NSOnState : NSOffState];
    }

    return YES;
}



- (void)installGlobalHotKeys {
    MASShortcut *globalShowShortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_K modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    NSData *globalLaunchShortcutData = [NSKeyedArchiver archivedDataWithRootObject:globalShowShortcut];

    [NSUserDefaults.standardUserDefaults registerDefaults:@{ kPreferenceGlobalShowShortcut : globalLaunchShortcutData }];
    
    [MASShortcutBinder.sharedBinder bindShortcutWithDefaultsKey:kPreferenceGlobalShowShortcut toAction:^{
        [self showAndActivateStrongbox];
    }];
}




























































    










    
    
    








- (void)customizeMenu {
    [self removeUnwantedMenuItems];

    NSMenu* topLevelMenuItem = [NSApplication.sharedApplication.mainMenu itemWithTag:kTopLevelMenuItemTagStrongbox].submenu;
    
    NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.action == @selector(onAbout:);
    }];
    
    if( topLevelMenuItem &&  index != NSNotFound) {
        NSMenuItem* menuItem = [topLevelMenuItem itemAtIndex:index];
        
        NSString* fmt = Settings.sharedInstance.fullVersion ? NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@") : NSLocalizedString(@"prefs_vc_app_version_info_none_pro_fmt", @"About Strongbox %@");
        
        NSString* about = [NSString stringWithFormat:fmt, [Utils getAppVersion]];

        menuItem.title = about;
    }
    
    if ( Settings.sharedInstance.fullVersion ) {
        [self removeMenuItem:kTopLevelMenuItemTagStrongbox action:@selector(onUpgradeToFullVersion:)];
    }
}

- (IBAction)onAbout:(id)sender {
    [AboutViewController show];
}

- (void)removeUnwantedMenuItems {
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(duplicateDocument:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(saveDocumentAs:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(renameDocument:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(revertDocumentToSaved:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(moveDocument:)];


    
    
    
    
    NSMenu* fileMenu = [NSApplication.sharedApplication.mainMenu itemWithTag:kTopLevelMenuItemTagFile].submenu;
    NSInteger openDocumentMenuItemIndex = [fileMenu indexOfItemWithTarget:nil andAction:@selector(openDocument:)];

    if (openDocumentMenuItemIndex>=0 &&
        [[fileMenu itemAtIndex:openDocumentMenuItemIndex+1] hasSubmenu])
    {
        
        
        
        [fileMenu removeItemAtIndex:openDocumentMenuItemIndex+1];
    }
    
    
    

}

- (void)removeMenuItem:(NSInteger)topLevelTag action:(SEL)action {
    NSMenu* topLevelMenuItem = [NSApplication.sharedApplication.mainMenu itemWithTag:topLevelTag].submenu;
    
    NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.action == action;
    }];
    
    if( topLevelMenuItem &&  index != NSNotFound) {

        [topLevelMenuItem removeItemAtIndex:index];
    }
    else {
        NSLog(@"WARN: Menu Item %@ not found to remove.", NSStringFromSelector(action));
    }
}

- (void)changeMenuItemKeyEquivalent:(NSInteger)topLevelTag action:(SEL)action keyEquivalent:(NSString*)keyEquivalent modifierMask:(NSEventModifierFlags)modifierMask {
    NSMenu* topLevelMenuItem = [NSApplication.sharedApplication.mainMenu itemWithTag:topLevelTag].submenu;
    
    NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.action == action;
    }];
    
    if( topLevelMenuItem && index != NSNotFound) {
        NSMenuItem* menuItem = [topLevelMenuItem itemAtIndex:index];
        if ( menuItem ) {
            [menuItem setKeyEquivalentModifierMask:modifierMask];
            [menuItem setKeyEquivalent:keyEquivalent];
        }
    }
    else {
        NSLog(@"WARN: Menu Item %@ not found to remove.", NSStringFromSelector(action));
    }
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {














    
    return NO;
}

- (IBAction)onViewDatabases:(id)sender {
    [DatabasesManagerVC show];
}

- (IBAction)onPreferences:(id)sender {
    [PreferencesWindowController.sharedInstance show];
}

- (IBAction)onUpgradeToFullVersion:(id)sender {
    [self showUpgradeModal:0];
}

- (void)showUpgradeModal:(NSInteger)delay {
    if(!self.validProducts || self.validProducts == 0) {
        [self getValidIapProducts];
    }
    else {
        SKProduct* product = [_validProducts objectAtIndex:0];        
        [UpgradeWindowController show:product cancelDelay:delay];
    }
}

- (IBAction)onContactSupport:(id)sender {
    [MacAlerts yesNo:NSLocalizedString(@"prompt_title_copy_debug_info", @"Copy Debug Info?") informativeText:NSLocalizedString(@"prompt_message_copy_debug_info", @"Would you like to copy some helpful debug information that you can share with support before proceeding?") window:NSApplication.sharedApplication.mainWindow completion:^(BOOL yesNo) {
        if ( yesNo ) {
            NSString* debug = [DebugHelper getAboutDebugString];
            [ClipboardManager.sharedInstance copyConcealedString:debug];
        }
    
        NSURL* url = [NSURL URLWithString:@"https:
        if (@available(macOS 10.15, *)) {
            [[NSWorkspace sharedWorkspace] openURL:url
                                     configuration:NSWorkspaceOpenConfiguration.configuration
                                 completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                if ( error ) {
                    NSLog(@"Launch URL done. Error = [%@]", error);
                }
            }];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:url];
        }
    }];
}
































- (void)onPreferencesChanged:(NSNotification*)notification {
    NSLog(@"Preferences Have Changed Notification Received... Resetting Clipboard Clearing Tasks");

    [self initializeClipboardWatchingTask];
    [self showHideSystemStatusBarIcon];
}

- (void)applicationWillBecomeActive:(NSNotification *)notification {

    [self initializeClipboardWatchingTask];
}

- (void)initializeClipboardWatchingTask {
    [self killClipboardWatchingTask];
    
    if(Settings.sharedInstance.clearClipboardEnabled) {
        [self startClipboardWatchingTask];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {

    [self killClipboardWatchingTask];
}

- (void)startClipboardWatchingTask {

    self.currentClipboardVersion = -1;
    
    self.clipboardChangeWatcher = [NSTimer scheduledTimerWithTimeInterval:0.5f
                                     target:self
                                   selector:@selector(checkClipboardForChangesAndNotify)
                                   userInfo:nil
                                    repeats:YES];

    





}

- (void)killClipboardWatchingTask {

    
    self.currentClipboardVersion = -1;
    
    if(self.clipboardChangeWatcher != nil) {
        [self.clipboardChangeWatcher invalidate];
        self.clipboardChangeWatcher = nil;
    }
}

- (void)checkClipboardForChangesAndNotify {
    
    
    if(self.currentClipboardVersion == -1) { 
        self.currentClipboardVersion = NSPasteboard.generalPasteboard.changeCount;
    }
    if(self.currentClipboardVersion != NSPasteboard.generalPasteboard.changeCount) {
        [self onStrongboxDidChangeClipboard];
        self.currentClipboardVersion = NSPasteboard.generalPasteboard.changeCount;
    }
    
    NSPasteboard* appCustomPasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    BOOL somethingOnAppCustomClipboard = [appCustomPasteboard dataForType:kDragAndDropExternalUti] != nil;
    if(somethingOnAppCustomClipboard && Settings.sharedInstance.clearClipboardEnabled) {
        [self scheduleClipboardClearTask];
    }
}

static NSInteger clipboardChangeCount;

- (void)onStrongboxDidChangeClipboard {
    NSLog(@"onApplicationDidChangeClipboard...");
    
    if(Settings.sharedInstance.clearClipboardEnabled) {
        clipboardChangeCount = NSPasteboard.generalPasteboard.changeCount;
        NSLog(@"Clipboard Changed and Clear Clipboard Enabled... Recording Change Count as [%ld]", (long)clipboardChangeCount);
        [self scheduleClipboardClearTask];
    }
}

- (void)scheduleClipboardClearTask {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(Settings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)),
       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
           [self clearClipboardWhereAppropriate];
       });
}

- (void)clearClipboardWhereAppropriate {
    if(clipboardChangeCount == NSPasteboard.generalPasteboard.changeCount) {
        NSLog(@"General Clipboard change count matches after time delay... Clearing Clipboard");
        [NSPasteboard.generalPasteboard clearContents];
    }
    else {

    }
    
    [self clearAppCustomClipboard];
}

- (void)clearAppCustomClipboard {
    NSPasteboard* appCustomPasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    
    @synchronized (self) {
        if([appCustomPasteboard canReadItemWithDataConformingToTypes:@[kDragAndDropExternalUti]]) {
            [appCustomPasteboard clearContents];
            NSLog(@"Clearing Custom App Pasteboard!");
        }
    }
}

- (IBAction)onFloatOnTopToggle:(id)sender {
    Settings.sharedInstance.floatOnTop = !Settings.sharedInstance.floatOnTop;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}






@end
