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
#import "MacAlerts.h"
#import "Utils.h"
#import "Strongbox.h"
#import "BiometricIdHelper.h"
#import "SafeStorageProviderFactory.h"
#import "AboutViewController.h"
#import "ClipboardManager.h"
#import "DebugHelper.h"
#import "MacUrlSchemes.h"
#import "Shortcut.h"
#import "Document.h"
#import "SystemTrayViewController.h"
#import "MainWindow.h"
#import "LockScreenViewController.h"
#import "CsvImporter.h"
#import "Csv.h"
#import "NSArray+Extensions.h"
#import "CreateDatabaseOrSetCredentialsWizard.h"
#import "MacSyncManager.h"
#import "macOSSpinnerUI.h"
#import "Constants.h"
#import "Serializator.h"
#import "MacCustomizationManager.h"
#import "ProUpgradeIAPManager.h"
#import "UpgradeWindowController.h"
#import "AutoFillProxyServer.h"
#import "Strongbox-Swift.h"
#import "SSHAgentServer.h"
#import "DatabasesManager.h"
#import "KeyFileManagement.h"
#import "WebDAVConnectionsManager.h"

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    #import "GoogleDriveStorageProvider.h"
    #import "DropboxV2StorageProvider.h"
#endif

#ifndef NO_NETWORKING
    #import "WebDAVStorageProvider.h"
    #import "SFTPStorageProvider.h"
    #import "WebDAVConnections.h"
    #import "SFTPConnections.h"
    #import "SFTPConnectionsManager.h"
#endif

#import "MacFileBasedBookmarkStorageProvider.h"
#import <UserNotifications/UserNotifications.h>
#import "SBLog.h"

NSString* const kUpdateNotificationQuickRevealStateChanged = @"kUpdateNotificationQuickRevealStateChanged";
static NSString* const kAutoLockIfInBackgroundNotification = @"autoLockAppInBackgroundTimeout";

const NSInteger kTopLevelMenuItemTagStrongbox = 1110;
const NSInteger kTopLevelMenuItemTagFile = 1111;
const NSInteger kTopLevelMenuItemTagView = 1113;



@interface AppDelegate () < NSMenuDelegate, NSPopoverDelegate >

@property NSTimer* clipboardChangeWatcher;
@property NSInteger currentClipboardVersion;
@property NSTimer* timerRefreshOtp;
@property NSDate* appLaunchTime;

@property BOOL firstActivationDone;
@property BOOL wasLaunchedAsLoginItem;

@property (strong, nonatomic) dispatch_block_t autoLockWorkBlock;
@property (readonly) BOOL quitsToSystemTrayInsteadOfTerminates;
@property (readonly) BOOL isQuitFromDockEvent;

@property NSMenu *systemTrayNewMenu;
@property NSStatusItem* statusItem;
@property NSPopover* systemTrayPopover;
@property NSDate* systemTrayPopoverClosedAt;

@end

@implementation AppDelegate

- (id)init {
    self = [super init];
    
    
    
    
    DocumentController *dc = [[DocumentController alloc] init];
    
    if(dc) {} 
    
    return self;
}

- (BOOL)isWasLaunchedAsLoginItem {
    return self.wasLaunchedAsLoginItem;
}

- (void)determineIfLaunchedAsLoginItem {
    
    
    
    
    NSAppleEventDescriptor* event = NSAppleEventManager.sharedAppleEventManager.currentAppleEvent;
    if ( event.eventID == kAEOpenApplication &&
        [[event paramDescriptorForKeyword:keyAEPropData] enumCodeValue] == keyAELaunchedAsLogInItem) {
        slog(@"Strongbox was launched as a login item!");
        self.wasLaunchedAsLoginItem = YES;
    }
    else {
        
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    
    
    
    [self determineIfLaunchedAsLoginItem];
    
    
    
    
    [self initializeInstallSettingsAndLaunchCount];
    
    [self doInitialSetup];
    
    [self listenToEvents];
    
    if ( Settings.sharedInstance.appAppearance != kAppAppearanceSystem ) {
        NSApp.appearance = Settings.sharedInstance.appAppearance == kAppAppearanceLight ?
        [NSAppearance appearanceNamed:NSAppearanceNameAqua] : [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self doDeferredAppLaunchTasks]; 
    });
}

- (void)doDeferredAppLaunchTasks {
    [self startOrStopAutoFillProxyServer];
    
    [self startOrStopSSHAgent];
    
    [self startOrStopWiFiSyncServer];
    
#ifndef NO_NETWORKING
    [self initializeCloudKit];
#endif
    
    [MacOnboardingManager beginAppOnboardingWithCompletion:^{
        
        
        [self checkForAllWindowsClosedScenario:nil appIsLaunching:YES];
    }];
    
    [self monitorForQuickRevealKey];
    
    [MacSyncManager.sharedInstance backgroundSyncOutstandingUpdates];
    
    
    
}



#ifndef NO_NETWORKING
- (void)initializeCloudKit {
    [CloudKitDatabasesInteractor.shared initializeWithCompletionHandler:^(NSError * _Nullable error ) {
        if ( error ) {
            slog(@"🔴 Error initializing CloudKit: [%@]", error);
        }
        else {
            slog(@"🟢 CloudKit successfully initialized.");
        }
    }];
}

- (void)application:(NSApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    slog(@"🟢 didRegisterForRemoteNotificationsWithDeviceToken");
    
    [CloudKitDatabasesInteractor.shared onRegisteredForRemoteNotifications:YES error:nil];
}

- (void)application:(NSApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    slog(@"🔴 didFailToRegisterForRemoteNotificationsWithError - [%@]", error);
    
    [CloudKitDatabasesInteractor.shared onRegisteredForRemoteNotifications:NO error:error];
}

- (void)application:(NSApplication *)application didReceiveRemoteNotification:(NSDictionary<NSString *,id> *)userInfo {
    [CloudKitDatabasesInteractor.shared onCloudKitDatabaseChangeNotification];
}

- (void)application:(NSApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)metadata {
    slog(@"userDidAcceptCloudKitShareWithMetadata: [%@]", metadata);
    
    [DBManagerPanel.sharedInstance show]; 
    
    
    
    [CloudKitDatabasesInteractor.shared acceptShareWithMetadata:metadata
                                              completionHandler:^(NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                slog(@"🔴 acceptShareWithMetadata done with [%@]", error);
                
                [MacAlerts error:error window:DBManagerPanel.sharedInstance.window];
            }
            else {
                slog(@"acceptShareWithMetadata done with [%@]", error);
            }
        });
    }];
    
}



- (void)startWiFiSyncObservation {
    if ( !StrongboxProductBundle.supportsWiFiSync || Settings.sharedInstance.disableWiFiSyncClientMode ) {
        return;
    }
    
    slog(@"AppDelegate::startWiFiSyncObservation...");
    
    [WiFiSyncBrowser.shared startBrowsing:NO
                               completion:^(BOOL success) {
        if ( !success ) {
            slog(@"🔴 Could not start WiFi Browser! error = [%@]", WiFiSyncBrowser.shared.lastError);
        }
        else {
            slog(@"🟢 WiFiBrowser Started");
        }
    }];
}

#endif

- (void)startOrStopSSHAgent {
    if ( Settings.sharedInstance.runSshAgent && Settings.sharedInstance.isPro ) {
        if ( ![SSHAgentServer.sharedInstance start] ) {
            slog(@"🔴 Failed to start SSH Agent.");
        }
        else {
            
        }
    }
    else {
        if ( SSHAgentServer.sharedInstance.isRunning ) {
            [SSHAgentServer.sharedInstance stop];
            slog(@"🔴 Stopped SSH Agent");
        }
    }
}

- (void)startOrStopAutoFillProxyServer {
    if ( Settings.sharedInstance.runBrowserAutoFillProxyServer && Settings.sharedInstance.isPro ) {
        [NativeMessagingManifestInstallHelper installNativeMessagingHostsFiles];
        
        if ( ![AutoFillProxyServer.sharedInstance start] ) {
            slog(@"🔴 Failed to start AutoFillProxyServer.");
        }
        else {
            slog(@"✅ Started AutoFill Proxy");
        }
    }
    else {
        [NativeMessagingManifestInstallHelper removeNativeMessagingHostsFiles];
        
        if ( AutoFillProxyServer.sharedInstance.isRunning ) {
            [AutoFillProxyServer.sharedInstance stop];
            slog(@"🔴 Stopped AutoFill Proxy");
        }
    }
}

- (void)startOrStopWiFiSyncServer {
    NSError* error;
    if (! [WiFiSyncServer.shared startOrStopWiFiSyncServerAccordingToSettingsAndReturnError:&error] ) {
        slog(@"🔴 Could not start WiFi Sync Server: [%@]", error);
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    [Settings.sharedInstance incrementLaunchCount];
    
    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = NSDate.date;
    }
}

- (void)doInitialSetup {
#ifdef DEBUG
    
    
    [NSUserDefaults.standardUserDefaults setValue:@(NO) forKey:@"NSConstraintBasedLayoutLogUnsatisfiable"];
    [NSUserDefaults.standardUserDefaults setValue:@(NO) forKey:@"__NSConstraintBasedLayoutLogUnsatisfiable"];
#else
    [self cleanupWorkingDirectories];
#endif
    
    self.appLaunchTime = [NSDate date];
    
    [MacCustomizationManager applyCustomizations];
    
    [self installGlobalHotKeys];
    
    [self removeUnwantedMenuItems];
    
    [self setupSystemTrayPopover];
    
    [self showHideSystemStatusBarIcon];
    
    [self clearAsyncUpdateIdsAndEphemeralOfflineFlags]; 
    
    [self startRefreshOtpTimer];
    
    [self bindFreeOrProStatus];
    
    if ( !MacCustomizationManager.isAProBundle ) {
        [ProUpgradeIAPManager.sharedInstance initialize]; 
    }
    
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [DropboxV2StorageProvider.sharedInstance initialize:Settings.sharedInstance.useIsolatedDropbox];
#endif
}

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;
    
    if( ( Settings.sharedInstance.launchCount > 30 && minutes > 2 ) || minutes > 20 ) { 
        if ( StrongboxProductBundle.isBusinessBundle ) {
            [BusinessActivation regularEntitlementCheckWithCompletionHandler:^(NSError * _Nullable error) { }];
        }
        else {
            [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate];
        }
    }
}

- (void)monitorForQuickRevealKey {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged
                                          handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        if ( ( event.keyCode == 58 || event.keyCode == 61 ) && Settings.sharedInstance.quickRevealWithOptionKey ) {
            BOOL optionKeyDown = ((event.modifierFlags & NSEventModifierFlagOption) == NSEventModifierFlagOption);
            
            
            
            [NSNotificationCenter.defaultCenter postNotificationName:kUpdateNotificationQuickRevealStateChanged
                                                              object:@(optionKeyDown)
                                                            userInfo:nil];
        }
        
        return event;
    }];
}

- (void)listenToEvents {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowDidMiniaturize:)
                                                 name:NSWindowDidMiniaturizeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onWindowWillClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:nil];
    
    
    
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onSettingsChanged:)
                                                 name:kSettingsChangedNotification
                                               object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onProStatusChanged:) name:kProStatusChangedNotification object:nil];
    
    
    
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self
                                                     andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                   forEventClass:kInternetEventClass
                                                      andEventID:kAEGetURL];
    
    
    
    
    
    
    
}

- (void)cleanupWorkingDirectories {
    [StrongboxFilesManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
    [StrongboxFilesManager.sharedInstance deleteAllTmpWorkingFiles];
}

- (BOOL)isWindowOfInterest:(NSNotification*)notification {
    return ( [notification.object isMemberOfClass:MainWindow.class] ||
            [notification.object isMemberOfClass:DatabasesManagerWindow.class] ||
            [notification.object isMemberOfClass:AppPreferencesWindow.class] ||
            [notification.object isMemberOfClass:PasswordGeneratorWindow.class] ||
            [notification.object isMemberOfClass:NextGenWindow.class]);
}

- (void)onWindowWillClose:(NSNotification*)notification {
    
    
    if ( ![self isWindowOfInterest:notification] ) { 
                                                     
        return;
    }
    
    [self checkForAllWindowsClosedScenario:notification.object appIsLaunching:NO];
}

- (void)onWindowDidMiniaturize:(NSNotification*)notification {
    
    
    if ( ![self isWindowOfInterest:notification] ) { 
                                                     
        return;
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    [self checkForAllWindowsClosedScenario:nil appIsLaunching:NO];
}

- (void)checkForAllWindowsClosedScenario:(NSWindow*)windowAboutToBeClosed appIsLaunching:(BOOL)appIsLaunching {
    slog(@"✅ AppDelegate::checkForAllWindowsClosedScenario - currentEvent = [%@]", NSApp.currentEvent);
    
    NSArray* docs = DocumentController.sharedDocumentController.documents;
    NSMutableArray* mainWindows = [docs map:^id _Nonnull(id  _Nonnull obj, NSUInteger idx) {
        Document* doc = obj;
        NSWindowController* wc = (NSWindowController*)doc.windowControllers.firstObject;
        return wc.window;
    }].mutableCopy;
    
    
    
    
    
    if ( windowAboutToBeClosed ) {
        
        [mainWindows removeObject:windowAboutToBeClosed];
    }
    
    BOOL allMiniaturizedOrClosed = [mainWindows allMatch:^BOOL(NSWindow * _Nonnull obj) {
        return obj.miniaturized;
    }];
    
    if ( allMiniaturizedOrClosed ) {
        [self onAllWindowsClosed:windowAboutToBeClosed appIsLaunching:appIsLaunching];
    }
    else {
        
        
        
        
        
        
        
    }
}

- (void)onAllWindowsClosed:(NSWindow*)windowAboutToBeClosed appIsLaunching:(BOOL)appIsLaunching {
    slog(@"🐞 onAllWindowsClosed");
    
    if ( appIsLaunching ) {
        if ( Settings.sharedInstance.showDatabasesManagerOnAppLaunch ) {
            if ( self.isWasLaunchedAsLoginItem && Settings.sharedInstance.showSystemTrayIcon ) {
                slog(@"🐞 AppDelegate::onAllWindowsClosed -> App Launching and no windows visible but was launched as a login item so NOP - Silent Launch - Hiding Dock Icon");
                
                [self showHideDockIcon:NO];
            }
            else {
                slog(@"🐞 AppDelegate::onAllWindowsClosed -> App Launching and no windows visible - Showing Databases Manager because so configured");
                
                [DBManagerPanel.sharedInstance show];
            }
        }
        else if ( Settings.sharedInstance.configuredAsAMenuBarApp ) {
            
            slog(@"🐞 AppDelegate::onAllWindowsClosed -> App Launching and no windows visible - Running as a tray app so NOT showing Databases Manager");
            
            [self showHideDockIcon:NO];
        }
    }
    else {
        
        
        
        
        
        
        
        
        
        
        if ( Settings.sharedInstance.configuredAsAMenuBarApp ) {
            slog(@"✅ AppDelegate::onAllWindowsClosed -> all windows have either just been miniaturized or closed... running as a tray app - hiding dock icon.");
            
            [self showHideDockIcon:NO];
        }
        else {
            slog(@"✅ AppDelegate::onAllWindowsClosed -> all windows have either just been miniaturized or closed... but configured to do nothing special.");
        }
        
    }
}

- (void)showHideDockIcon:(BOOL)show {
    slog(@"🚀 AppDelegate::showHideDockIcon: [%@] - [%@]", (long)show ? @"SHOW" : @"HIDE", NSThread.currentThread);
    
    if ( show ) {
        if ( NSApp.activationPolicy != NSApplicationActivationPolicyAccessory ) {
            slog(@"Dock Icon already visible - NOP"); 
            return;
        }
        
        
        
        
        
        
        
        
        
        
        
        BOOL ret = [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        slog(@"🚀 AppDelegate::NSApplicationActivationPolicyProhibited: %@", localizedYesOrNoFromBool(ret));
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL ret = [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
            slog(@"🚀 AppDelegate::NSApplicationActivationPolicyRegular: %@", localizedYesOrNoFromBool(ret));
            
            
            
            
            [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)]; 
            
            [NSApp arrangeInFront:nil];
            
            slog(@"🚀 AppDelegate::showHideDockIcon: mainWindow = [%@]", NSApplication.sharedApplication.mainWindow);
            
            [NSApplication.sharedApplication.mainWindow makeKeyAndOrderFront:nil];
        });
    }
    else {
        
        
        
        
        BOOL ret = [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        slog(@"🚀 AppDelegate::NSApplicationActivationPolicyAccessory: %@", localizedYesOrNoFromBool(ret));
    }
}



- (BOOL)isHiddenToTray {
    BOOL ret = NSApp.activationPolicy != NSApplicationActivationPolicyRegular;
    
    
    
    return ret;
}

- (void)showHideSystemStatusBarIcon {
    
    
    if (Settings.sharedInstance.showSystemTrayIcon) {
        if (!self.statusItem) {
            NSImage* statusImage = [NSImage imageNamed:@"AppIcon-glyph"];
            statusImage.size = NSMakeSize(18.0, 18.0);
            self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
            self.statusItem.button.image = statusImage;
            
            self.statusItem.highlightMode = YES;
            self.statusItem.button.enabled = YES;
            
            self.systemTrayNewMenu = [[NSMenu alloc] init];
            self.systemTrayNewMenu.title = @"Strongbox";
            self.systemTrayNewMenu.delegate = self;
            
            [self refreshSystemTrayNewMenu];
            
            [self.statusItem.button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
            self.statusItem.button.action = @selector(onSystemTrayIconClicked:);
        }
    }
    else {
        if(self.statusItem) {
            [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
            self.statusItem = nil;
        }
    }
}

- (NSMenuItem*)createClickActionMenuItem:(NSString*)title action:(SystemMenuClickAction)action {
    NSMenuItem* foo = [[NSMenuItem alloc] init];
    
    foo.title = title;
    foo.state = Settings.sharedInstance.systemMenuClickAction == action ? NSControlStateValueOn : NSControlStateValueOff;
    foo.tag = action;
    foo.action = @selector(onClickSystemTrayClickAction:);
    
    return foo;
}

- (void)onClickSystemTrayClickAction:(id)sender {
    NSMenuItem* m = sender;
    SystemMenuClickAction action = m.tag;
    Settings.sharedInstance.systemMenuClickAction = action;
}

- (void)refreshSystemTrayNewMenu {
    [self.systemTrayNewMenu removeAllItems];
    
    MASShortcut* globalShowShortcut = [MASShortcutBinder.sharedBinder valueForKey:kPreferenceGlobalShowShortcutNotification];
    MASShortcut* showQuickSearchShortcut = [MASShortcutBinder.sharedBinder valueForKey:kPreferenceLaunchQuickSearchShortcut];
    MASShortcut* showPasswordGeneratorShortcut = [MASShortcutBinder.sharedBinder valueForKey:kPreferencePasswordGeneratorShortcut];
    
    NSMenuItem* mu = [[NSMenuItem alloc] init];
    
    mu.title = NSLocalizedString(@"system_tray_menu_item_show", @"Show Strongbox");
    mu.action = @selector(onSystemTrayShow:);
    
    if ( globalShowShortcut ) {
        mu.keyEquivalent = globalShowShortcut.keyCodeStringForKeyEquivalent;
        mu.keyEquivalentModifierMask = globalShowShortcut.modifierFlags;
    }
    
    [self.systemTrayNewMenu addItem:mu];
    
    NSMenuItem* mu2 = [[NSMenuItem alloc] init];
    
    mu2.title = NSLocalizedString(@"system_tray_menu_item_show_quick_search", @"Show Quick Search");
    mu2.action = @selector(showQuickSearchPalette:);
    
    if ( showQuickSearchShortcut ) {
        mu2.keyEquivalent = showQuickSearchShortcut.keyCodeStringForKeyEquivalent;
        mu2.keyEquivalentModifierMask = showQuickSearchShortcut.modifierFlags;
    }
    
    [self.systemTrayNewMenu addItem:mu2];
    
    
    
    [self.systemTrayNewMenu addItemWithTitle:NSLocalizedString(@"system_tray_menu_item_show_databases_manager", @"Show Databases Manager") action:@selector(onTrayShowViewDatabases:) keyEquivalent:@"d"];
    
    
    
    if ( showPasswordGeneratorShortcut ) {
        NSMenuItem* mu2 = [[NSMenuItem alloc] init];
        
        mu2.title = NSLocalizedString(@"system_tray_menu_item_show_password_generator", @"Show Password Generator");
        mu2.action = @selector(onTrayShowPasswordGenerator:);
        mu2.keyEquivalent = showPasswordGeneratorShortcut.keyCodeStringForKeyEquivalent;
        mu2.keyEquivalentModifierMask = showPasswordGeneratorShortcut.modifierFlags;
        
        [self.systemTrayNewMenu addItem:mu2];
    }
    else {
        [self.systemTrayNewMenu addItemWithTitle:NSLocalizedString(@"system_tray_menu_item_show_password_generator", @"Show Password Generator") action:@selector(onTrayShowPasswordGenerator:) keyEquivalent:@"G"];
    }
    
    
    
    [self.systemTrayNewMenu addItem:NSMenuItem.separatorItem];
    
    NSMenuItem* clickAction = [[NSMenuItem alloc] init];
    
    clickAction.title = NSLocalizedString(@"configure_click_action", @"Configure Click Action");
    [self.systemTrayNewMenu addItem:clickAction];
    
    NSMenu* sub = [[NSMenu alloc] init];
    
    [sub addItem:[self createClickActionMenuItem:NSLocalizedString(@"quick_search", @"Quick Search") action:kSystemMenuClickActionQuickSearch]];
    [sub addItem:[self createClickActionMenuItem:NSLocalizedString(@"system_tray_menu_item_show", @"Show Strongbox") action:kSystemMenuClickActionShowStrongbox]];
    [sub addItem:[self createClickActionMenuItem:NSLocalizedString(@"popout_password_generator", @"Password Generator") action:kSystemMenuClickActionPasswordGenerator]];
    [sub addItem:[self createClickActionMenuItem:NSLocalizedString(@"show_this_menu", @"Show this Menu") action:kSystemMenuClickActionShowMenu]];
    
    clickAction.submenu = sub;
    
    [self.systemTrayNewMenu addItem:NSMenuItem.separatorItem];
    
    
    
    NSImage * locked = [NSImage imageWithSystemSymbolName:@"lock" accessibilityDescription:nil];
    NSImage * locked2 = [locked imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge]];
    
    NSImageSymbolConfiguration* config = [[NSImageSymbolConfiguration configurationWithPaletteColors:@[NSColor.systemGreenColor]] configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge]];
    
    NSImage * unlocked = [NSImage imageWithSystemSymbolName:@"lock.open" accessibilityDescription:nil];
    NSImage * unlocked3 = [unlocked imageWithSymbolConfiguration:config];
    
    int i = 0;
    for ( MacDatabasePreferences* database in MacDatabasePreferences.allDatabases ) {
        NSMenuItem* mu = [[NSMenuItem alloc] init];
        
        mu.title = database.nickName;
        mu.action = @selector(onSystemTrayShowDatabase:);
        mu.representedObject = database.uuid;
        mu.image = [DatabasesCollection.shared isUnlockedWithUuid:database.uuid] ? unlocked3 : locked2;
        mu.keyEquivalent = @(++i).stringValue;
        
        [self.systemTrayNewMenu addItem:mu];
    }
    
    [self.systemTrayNewMenu addItem:NSMenuItem.separatorItem];
    
    [self.systemTrayNewMenu addItemWithTitle:NSLocalizedString(@"system_tray_menu_item_lock_all", @"Lock All") action:@selector(onSystemTrayLockAll:) keyEquivalent:@"l"];
    [self.systemTrayNewMenu addItemWithTitle:NSLocalizedString(@"generic_settings", @"Settings") action:@selector(onTrayShowAppSettings:) keyEquivalent:@","];
    [self.systemTrayNewMenu addItemWithTitle:NSLocalizedString(@"system_tray_menu_item_quit", @"Quit Strongbox") action:@selector(onStrongboxQuitFromTray:) keyEquivalent:@"q"];
}

- (void)onSystemTrayLockAll:(id)sender {
    [DatabasesCollection.shared tryToLockAll];
}

- (void)setupSystemTrayPopover {
    self.systemTrayPopover = [[NSPopover alloc] init];
    self.systemTrayPopover.behavior = NSPopoverBehaviorTransient ;
    self.systemTrayPopover.animates = YES;
    
    PasswordGenerationPreferences* vc =  [PasswordGenerationPreferences fromStoryboard];
    
    self.systemTrayPopover.contentViewController = vc;
    self.systemTrayPopover.delegate = self;
}

- (void)popoverDidClose:(NSNotification *)notification {
    
    
    
    
    
    
    self.systemTrayPopoverClosedAt = NSDate.date;
}

- (void)onSystemTrayIconClicked:(id)sender {
    
    
    if ( YES ) {
        if ( NSApp.currentEvent.type == NSEventTypeLeftMouseUp ) {
            switch (Settings.sharedInstance.systemMenuClickAction ) {
                case kSystemMenuClickActionQuickSearch:
                    [self showQuickSearchPalette:sender];
                    break;
                case kSystemMenuClickActionPasswordGenerator:
                    [self showPasswordGeneratorTrayMenuBarPopover:sender];
                    break;
                case kSystemMenuClickActionShowStrongbox:
                    [self onSystemTrayShow:sender];
                    break;
                default:
                    [self showSystemTrayNewMenu:sender];
                    break;
            }
        } else {
            [self showSystemTrayNewMenu:sender];
        }
    }
}

- (void)showPasswordGeneratorTrayMenuBarPopover:(id)sender {
    NSTimeInterval interval = [NSDate.date timeIntervalSinceDate:self.systemTrayPopoverClosedAt];
    
    
    
    
    if ( self.systemTrayPopoverClosedAt == nil || interval > 0.2f ) {
        
        NSView* statusBarItem = sender;
        [self.systemTrayPopover showRelativeToRect:statusBarItem.bounds ofView:sender preferredEdge:NSMaxYEdge];
        
        
        
        
        
        
        
        
        
        
        
        
        
        [self.systemTrayPopover.contentViewController.view.window makeKeyWindow]; 
    }
}

- (void)menuDidClose:(NSMenu *)menu {
    if ( menu == self.systemTrayNewMenu ) {
        self.statusItem.menu = nil; 
    }
}

- (void)showSystemTrayNewMenu:(id)sender {
    [self refreshSystemTrayNewMenu];
    self.statusItem.menu = self.systemTrayNewMenu;
    [self.statusItem.button performClick:nil];
}

- (IBAction)onSystemTrayShow:(id)sender {
    [self showAndActivateStrongbox:nil];
}

- (IBAction)onSystemTrayShowDatabase:(id)sender {
    NSMenuItem* mu = sender;
    NSString* databaseUuid = mu.representedObject;
    [self showAndActivateStrongbox:databaseUuid];
}



- (void)showAndActivateStrongbox:(NSString*_Nullable)databaseUuid {
    [self showAndActivateStrongbox:databaseUuid completion:nil];
}

- (void)showAndActivateStrongbox:(NSString*_Nullable)databaseUuid completion:(void (^_Nullable)(void))completion {
    [self showAndActivateStrongbox:databaseUuid suppressEmptyLaunchBehaviour:NO suppressWindowUnminimization:NO completion:completion];
}

- (void)showAndActivateStrongbox:(NSString*_Nullable)databaseUuid
    suppressEmptyLaunchBehaviour:(BOOL)suppressEmptyLaunchBehaviour
    suppressWindowUnminimization:(BOOL)suppressWindowUnminimization
                      completion:(void (^_Nullable)(void))completion {
    slog(@"🚀 showAndActivateStrongbox: [%@] - BEGIN", databaseUuid);
    
    [self showHideDockIcon:YES];
    
    if ( !suppressWindowUnminimization ) {
        for ( NSWindow* win in [NSApp windows] ) { 
            if([win isMiniaturized]) {
                [win deminiaturize:self];
            }
        }
    }
    
    DocumentController* dc = NSDocumentController.sharedDocumentController;
    
    if ( databaseUuid ) {
        MacDatabasePreferences* metadata = [MacDatabasePreferences fromUuid:databaseUuid];
        if ( metadata ) {
            [dc openDatabase:metadata completion:^(Document * document, NSError * error) {
                [self showAndActivateStrongboxStage2:completion];
            }];
        }
        else {
            slog(@"🔴 Unknown databaseUuid sent to showAndActivateStrongbox");
            
            [self showAndActivateStrongboxStage2:completion];
        }
    }
    else {
        slog(@"ℹ️ showAndActivateStrongbox - No Special Database Indicated");
        
        if ( !self.suppressQuickLaunchForNextAppActivation && !suppressEmptyLaunchBehaviour ) {
            slog(@"ℹ️ showAndActivateStrongbox - Quick Launch not suppressed...");
            [dc launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable];
        }
        else {
            slog(@"ℹ️ showAndActivateStrongbox - Suppressed Quick Launch");
            self.suppressQuickLaunchForNextAppActivation = NO; 
        }
        
        [self showAndActivateStrongboxStage2:completion];
    }
}

- (void)showAndActivateStrongboxStage2:(void (^_Nullable)(void))completion {
    [NSApplication.sharedApplication.mainWindow makeKeyAndOrderFront:nil];
    [NSApp arrangeInFront:nil];
    
    
    [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)]; 
    
    
    
    if ( completion ) {
        completion();
    }
    
    slog(@"🚀 showAndActivateStrongbox: END");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if(Settings.sharedInstance.clearClipboardEnabled) {
        [self clearClipboardWhereAppropriate];
    }
    
    
    
    [self clearAppCustomClipboard];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    slog(@"✅ applicationDidBecomeActive - START - [%@]", notification);
    
    
    
    [self cancelAutoLockTimer];
    
    [self performedScheduledEntitlementsCheck];
    
    if ( !self.firstActivationDone ) {
        self.firstActivationDone = YES;
        
        
        
        DocumentController* dc = NSDocumentController.sharedDocumentController;
        
        [dc onAppStartup];
    }
    
    if ( [self isHiddenToTray] ) {
        slog(@"✅ applicationDidBecomeActive - isHiddenToTray - showing dock icon and and activating");
        
        
        
        
        
        
        
        
        [self showAndActivateStrongbox:nil];
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
#ifndef NO_NETWORKING
    [self startWiFiSyncObservation];
    
    [self maybeWarnAboutCloudKitUnavailability];
#endif
    
    [self checkIfBiometricsDatabaseChanged];
    
    self.suppressQuickLaunchForNextAppActivation = NO; 
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    slog(@"✅ AppDelegate::applicationShouldHandleReopen: hasVisibleWindows = [%@]", localizedYesOrNoFromBool(hasVisibleWindows));
    
    
    
    
    if ( !hasVisibleWindows ) {
        DocumentController* dc = NSDocumentController.sharedDocumentController;
        [dc launchStartupDatabasesOrShowManagerIfNoDocumentsAvailable];
    }
    
    return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    slog(@"✅ AppDelegate::applicationShouldOpenUntitledFile");
    
    return NO;
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    
    
    [self startAutoLockTimer];
}

- (void)cancelAutoLockTimer {
    if(self.autoLockWorkBlock) {
        slog(@"🐞 DEBUG - Cancelling Background Auto-Lock work block");
        dispatch_block_cancel(self.autoLockWorkBlock);
        self.autoLockWorkBlock = nil;
    }
}

- (void)startAutoLockTimer {
    NSInteger timeout = Settings.sharedInstance.autoLockIfInBackgroundTimeoutSeconds;
    
    if(timeout != 0) {
        [self cancelAutoLockTimer];
        
        slog(@"🐞 DEBUG - [startAutoLockForAppInBackgroundTimer] Creating Background Auto-Lock work block... [timeout = %ld secs]", timeout);
        
        self.autoLockWorkBlock = dispatch_block_create(0, ^{
            slog(@"🐞 DEBUG - App in Background timeout exceeded -> Sending Notification...");
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kAutoLockIfInBackgroundNotification object:nil];
            self.autoLockWorkBlock = nil;
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), self.autoLockWorkBlock);
    }
}

- (void)randomlyShowUpgradeMessage {
    NSUInteger random = arc4random_uniform(100);
    
    NSUInteger showPercentage = 15;
    if(random < showPercentage) {
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) showUpgradeModal:YES];
    }
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];
    
    if (theAction == @selector(onFloatOnTopToggle:)) {
        NSMenuItem* item = (NSMenuItem*) anItem;
        [item setState:Settings.sharedInstance.floatOnTop ? NSControlStateValueOn : NSControlStateValueOff];
    }
    else if (theAction == @selector(signOutOfOneDrive:)) {
        return YES;
    }
    else if (theAction == @selector(signOutOfDropbox:)) {
        return YES; 
    }
    else if (theAction == @selector(signOutOfGoogleDrive:)) {
        return YES; 
    }
    
    return YES;
}

- (IBAction)signOutOfGoogleDrive:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [GoogleDriveManager.sharedInstance signout];
#endif
}

- (IBAction)signOutOfOneDrive:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [OneDriveStorageProvider.sharedInstance signOutAll];
#endif
}

- (IBAction)signOutOfDropbox:(id)sender {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [DropboxV2StorageProvider.sharedInstance signOut];
#endif
}



- (void)installGlobalHotKeys {
    MASShortcut* globalShowShortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_K modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagOption];
    NSData *globalLaunchShortcutData = [NSKeyedArchiver archivedDataWithRootObject:globalShowShortcut];
    
    MASShortcut* showQuickSearchShortcut = [MASShortcut shortcutWithKeyCode:kVK_ANSI_J modifierFlags:NSEventModifierFlagCommand | NSEventModifierFlagShift];
    NSData *globalQuickSearchShortcutData = [NSKeyedArchiver archivedDataWithRootObject:showQuickSearchShortcut];
    
    
    
    
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kPreferenceGlobalShowShortcutNotification : globalLaunchShortcutData,
        kPreferenceLaunchQuickSearchShortcut : globalQuickSearchShortcutData,
        
    }];
    
    [MASShortcutBinder.sharedBinder bindShortcutWithDefaultsKey:kPreferenceGlobalShowShortcutNotification toAction:^{
        [self showAndActivateStrongbox:nil];
    }];
    
    [MASShortcutBinder.sharedBinder bindShortcutWithDefaultsKey:kPreferenceLaunchQuickSearchShortcut toAction:^{
        [self showQuickSearchPalette:nil];
    }];
    
    [MASShortcutBinder.sharedBinder bindShortcutWithDefaultsKey:kPreferencePasswordGeneratorShortcut toAction:^{
        [self onTrayShowPasswordGenerator:nil];
    }];
    
    
    
    NSString *observableKeyPath = [@"values." stringByAppendingString:kPreferenceGlobalShowShortcutNotification];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:observableKeyPath
                                                                 options:kNilOptions
                                                                 context:kPreferenceGlobalShowShortcutNotification];
    
    observableKeyPath = [@"values." stringByAppendingString:kPreferenceLaunchQuickSearchShortcut];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:observableKeyPath
                                                                 options:kNilOptions
                                                                 context:kPreferenceLaunchQuickSearchShortcut];
    
    observableKeyPath = [@"values." stringByAppendingString:kPreferencePasswordGeneratorShortcut];
    
    [[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
                                                              forKeyPath:observableKeyPath
                                                                 options:kNilOptions
                                                                 context:kPreferencePasswordGeneratorShortcut];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)obj change:(NSDictionary *)change context:(void *)ctx {
    if (ctx == kPreferenceGlobalShowShortcutNotification || ctx == kPreferenceLaunchQuickSearchShortcut || ctx == kPreferencePasswordGeneratorShortcut) {
        slog(@"🐞 MASShortcut Changed...");
        [NSNotificationCenter.defaultCenter postNotificationName:kSettingsChangedNotification object:nil];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:obj change:change context:ctx];
    }
}

- (IBAction)onAbout:(id)sender {
    [AboutViewController show];
}

- (void)removeUnwantedMenuItems {
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(duplicateDocument:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(saveDocumentAs:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(renameDocument:)];
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(moveDocument:)];
    
    if ( !StrongboxProductBundle.supports3rdPartyStorageProviders ) {
        NSMenu* fileMenu = [NSApplication.sharedApplication.mainMenu itemWithTag:kTopLevelMenuItemTagFile].submenu;
        
        
        
        NSInteger idx = [fileMenu indexOfItemWithTag:24121980];
        [fileMenu removeItemAtIndex:idx];
    }
    
    if ( !StrongboxProductBundle.supportsSftpWebDAV ) {
        [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(onWebDAVConnectionsManager:)];
        [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(onSftpConnectionsManager:)];
    }
    
#ifndef DEBUG
    [self removeMenuItem:kTopLevelMenuItemTagFile action:@selector(onDumpXml:)];
#endif
    
    
    
    
    
    NSMenu* fileMenu = [NSApplication.sharedApplication.mainMenu itemWithTag:kTopLevelMenuItemTagFile].submenu;
    NSInteger openDocumentMenuItemIndex = [fileMenu indexOfItemWithTarget:nil andAction:@selector(originalOpenDocument:)];
    
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
        slog(@"WARN: Menu Item %@ not found to remove.", NSStringFromSelector(action));
    }
}

- (IBAction)onViewDatabases:(id)sender {
    [DBManagerPanel.sharedInstance show];
}

- (IBAction)onUpgradeToFullVersion:(id)sender {
    [self showUpgradeModal:NO];
}

- (void)showUpgradeModal:(BOOL)naggy {
    if ( MacCustomizationManager.isUnifiedFreemiumBundle ) {
        UnifiedUpgrade* uu = [UnifiedUpgrade fromStoryboard];
        
        uu.naggy = naggy;
        
        [uu presentInNewWindow];
    }
    else {
        [UpgradeWindowController show:naggy ? 1 : 0];
    }
}

- (IBAction)onShowTipJar:(id)sender {
    TipJarViewController* vc = [TipJarViewController fromStoryboard];
    [vc presentInNewWindow];
}




- (void)onSettingsChanged:(NSNotification*)notification {
    slog(@"AppDelegate::Settings Have Changed Notification Received... Resetting Clipboard Clearing Tasks");
    
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
    
    
    if ( Settings.sharedInstance.clearClipboardEnabled ) {
        clipboardChangeCount = NSPasteboard.generalPasteboard.changeCount;
        
        [self scheduleClipboardClearTask];
    }
}

- (void)scheduleClipboardClearTask {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(Settings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        
        
        [self clearClipboardWhereAppropriate];
    });
}

- (void)clearClipboardWhereAppropriate {
    if ( clipboardChangeCount == NSPasteboard.generalPasteboard.changeCount ) {
        slog(@"General Clipboard change count matches after time delay... Clearing Clipboard");
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
            slog(@"Clearing Custom App Clipboard!");
        }
    }
}

- (IBAction)onFloatOnTopToggle:(id)sender {
    Settings.sharedInstance.floatOnTop = !Settings.sharedInstance.floatOnTop;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSettingsChangedNotification object:nil];
}



- (IBAction)onImportFromCsvFile:(id)sender {
    [DBManagerPanel.sharedInstance show]; 
    
    NSString* loc = NSLocalizedString(@"mac_csv_file_must_contain_header_and_fields", @"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.");
    
    NSString* message = [NSString stringWithFormat:loc, kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderTotp, kCSVHeaderNotes];
    
    loc = NSLocalizedString(@"mac_csv_format_info_title", @"CSV Format");
    
    [MacAlerts info:loc
    informativeText:message
             window:NSApplication.sharedApplication.mainWindow
         completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self requestImportFile:[[CSVImporter alloc] init]];
        });
    }];
}

- (IBAction)onImportFromiCloudCsvFile:(id)sender {
    [self requestImportFile:[[iCloudImporter alloc] init] showGenericWarning:YES];
}

- (IBAction)onImportFromLastPassCsvFile:(id)sender {
    [self requestImportFile:[[LastPassImporter alloc] init] showGenericWarning:YES];
}

- (IBAction)onImportFromEnpassJson:(id)sender {
    [self requestImportFile:[[EnpassImporter alloc] init] showGenericWarning:YES];
}

- (IBAction)onImportFromBitwardenJson:(id)sender {
    [self requestImportFile:[[BitwardenImporter alloc] init] showGenericWarning:YES];
}

- (IBAction)onImport1Password1Pif:(id)sender {
    [DBManagerPanel.sharedInstance show]; 
    
    NSString* title = NSLocalizedString(@"1password_import_warning_title", @"1Password Import Warning");
    NSString* msg = NSLocalizedString(@"1password_import_warning_msg", @"The import process isn't perfect and some features of 1Password such as named sections are not available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");
    
    [MacAlerts info:title
    informativeText:msg
             window:DBManagerPanel.sharedInstance.window
         completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self requestImportFile:[[OnePasswordImporter alloc] init] showGenericWarning:NO];
        });
    }];
}

- (IBAction)onImport1Password1Pux:(id)sender {
    [DBManagerPanel.sharedInstance show]; 
    
    NSString* title = NSLocalizedString(@"1password_import_warning_title", @"1Password Import Warning");
    NSString* msg = NSLocalizedString(@"1password_import_warning_msg", @"The import process isn't perfect and some features of 1Password such as named sections are not available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");
    
    [MacAlerts info:title
    informativeText:msg
             window:DBManagerPanel.sharedInstance.window
         completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self requestImportFile:[[OnePassword1PuxImporter alloc] init] showGenericWarning:NO];
        });
    }];
}

- (void)requestImportFile:(NSObject<Importer>*)importer showGenericWarning:(BOOL)showGenericWarning {
    if ( showGenericWarning ) {
        [DBManagerPanel.sharedInstance show]; 
        
        NSString* title = NSLocalizedString(@"generic_import_warning_title", @"Import Warning");
        NSString* msg = NSLocalizedString(@"generic_import_warning_msg", @"The import process may not be perfect and some features may not be available in Strongbox.\n\nIt is important to check that your entries as acceptable after you have imported.");
        
        [MacAlerts info:title
        informativeText:msg
                 window:DBManagerPanel.sharedInstance.window
             completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestImportFile:importer];
            });
        }];
    }
    else {
        [self requestImportFile:importer];
    }
}

- (void)requestImportFile:(NSObject<Importer>*)importer {
    [DBManagerPanel.sharedInstance show]; 
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    NSString* loc = NSLocalizedString(@"mac_choose_file_import", @"Choose file to Import");
    [panel setTitle:loc];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setFloatingPanel:NO];
    panel.allowedFileTypes = importer.allowedFileTypes;
    
    NSInteger result = [panel runModal];
    if(result == NSModalResponseOK) {
        NSURL* url = panel.URLs.firstObject;
        if ( url ) {
            [self continueImportWithUrl:url importer:importer];
        }
    }
}

- (void)continueImportWithUrl:(NSURL*)url importer:(NSObject<Importer>*)importer {
    NSError* error;
    DatabaseModel* database;
    NSArray<ImportMessage*>* messages;
    
    if ( [importer respondsToSelector:@selector(convertExWithUrl:error:)] ) {
        ImportResult* result = [importer convertExWithUrl:url error:&error];
        database = result.database;
        messages = result.messages;
    }
    else {
        database = [importer convertWithUrl:url error:&error];
        messages = @[];
    }
    
    if ( error ) {
        slog(@"🔴 %@", error.localizedDescription);
        [MacAlerts error:error window:DBManagerPanel.sharedInstance.window];
    }
    else {
        if ( !database ) {
            [MacAlerts info:NSLocalizedString(@"import_failed_title", @"🔴 Import Failed")
            informativeText:NSLocalizedString(@"import_failed_message", @"Strongbox could not import this file. Please check it is in the correct format.")
                     window:DBManagerPanel.sharedInstance.window
                 completion:nil];
            return;
        }
        else {
            [self addImportedDatabase:database messages:messages];
        }
    }
}

- (void)addImportedDatabase:(DatabaseModel*)database messages:(NSArray<ImportMessage*>*)messages {
    NSViewController* presenter = DBManagerPanel.sharedInstance.contentViewController;
    
    NSViewController* vc = [SwiftUIViewFactory makeImportResultViewControllerWithMessages:messages
                                                                           dismissHandler:^(BOOL cancel) {
        [presenter dismissViewController:presenter.presentedViewControllers.firstObject];
        
        if ( !cancel ) {
            [self createNewImportedDatabase:database];
        }
    }];
    
    [DBManagerPanel.sharedInstance.contentViewController presentViewControllerAsSheet:vc];
}

- (void)createNewImportedDatabase:(DatabaseModel*)databaseModel {
    [DBManagerPanel.sharedInstance showAndBeginAddDatabaseSequenceWithCreateMode:YES newModel:databaseModel];
}

- (BOOL)shouldWaitForUpdatesOrSyncsToFinish {
    BOOL asyncUpdatesInProgress = [MacDatabasePreferences.allDatabases anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return obj.asyncUpdateId != nil;
    }];
    
    return asyncUpdatesInProgress || MacSyncManager.sharedInstance.syncInProgress;
}

- (void)closeAllDatabases {
    NSArray* docs = DocumentController.sharedDocumentController.documents;
    NSMutableArray* mainWindows = [docs map:^id _Nonnull(id  _Nonnull obj, NSUInteger idx) {
        Document* doc = obj;
        NSWindowController* wc = (NSWindowController*)doc.windowControllers.firstObject;
        return wc.window;
    }].mutableCopy;
    
    for ( NSWindow* window in mainWindows ) {
        [window close];
    }
}

- (IBAction)onStrongboxQuitFromTray:(id)sender {
    slog(@"✅ onStrongboxQuitFromTray...");

    [NSApplication.sharedApplication terminate:nil];
}

- (IBAction)onStrongboxQuit:(id)sender {
    slog(@"✅ onStrongboxQuit...");

    if ( self.quitsToSystemTrayInsteadOfTerminates ) {
        slog(@"✅ onStrongboxQuit => Should we actually? No -> Closing all windows instead");
        
        [self quitToSystemTrayInsteadOfTerminate];
    }
    else {
        slog(@"✅ onStrongboxQuit... Should we actually? YES terminating process");
        [NSApplication.sharedApplication terminate:nil];
    }
}

- (BOOL)quitsToSystemTrayInsteadOfTerminates {
    return Settings.sharedInstance.configuredAsAMenuBarApp && !Settings.sharedInstance.quitTerminatesProcessEvenInSystemTrayMode;
}

- (void)quitToSystemTrayInsteadOfTerminate {
    [self closeAllDatabases];
    
    [DBManagerPanel.sharedInstance close];
}

- (BOOL)isQuitFromDockEvent {
    
    
    
    
    NSAppleEventDescriptor* appleEvent = NSAppleEventManager.sharedAppleEventManager.currentAppleEvent;
    pid_t senderPID = [[appleEvent attributeDescriptorForKeyword:keySenderPIDAttr] int32Value];
    
    if ( appleEvent && appleEvent.eventID == kAEQuitApplication && senderPID != 0 ) {
        NSRunningApplication *sender = [NSRunningApplication runningApplicationWithProcessIdentifier:senderPID];
        
        return (sender && [@"com.apple.dock" isEqualToString:sender.bundleIdentifier] );
    }
    
    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if ( self.isQuitFromDockEvent && self.quitsToSystemTrayInsteadOfTerminates ) {
        slog(@"✅ Quit from Dock => Should we actually? No -> Closing all windows instead");
        
        [self quitToSystemTrayInsteadOfTerminate];
        
        return NSTerminateCancel;
    }
        
    [self stopRefreshOtpTimer];
    
    if ( [self shouldWaitForUpdatesOrSyncsToFinish] ) {
        
        
        [DBManagerPanel.sharedInstance show];
        
        [macOSSpinnerUI.sharedInstance show:NSLocalizedString(@"macos_quitting_finishing_sync", @"Quitting - Finishing Sync...")
                             viewController:DBManagerPanel.sharedInstance.contentViewController];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self waitForAllSyncToFinishThenTerminate];
        });
    
        slog(@"✅ applicationShouldTerminate? => Yes, but later finish sync first");

        return NSTerminateLater;
    }
    else {
        slog(@"✅ applicationShouldTerminate? => Yes, immediately");

        [DatabasesManager.sharedInstance forceSerialize];
        
        return NSTerminateNow;
    }
}

- (void)waitForAllSyncToFinishThenTerminate {
    if ( [self shouldWaitForUpdatesOrSyncsToFinish] ) {

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1. * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self waitForAllSyncToFinishThenTerminate];
        });
    }
    else {
        [macOSSpinnerUI.sharedInstance dismiss];

        [DatabasesManager.sharedInstance forceSerialize];
        
        slog(@"waitForAllSyncToFinishThenTerminate - All Syncs Done - Quitting app.");
        [NSApplication.sharedApplication replyToApplicationShouldTerminate:NSTerminateNow];
    }
}

- (void)onContactSupport:(id)sender {
    NSURL* launchableUrl = [NSURL URLWithString:@"https:
    
    [[NSWorkspace sharedWorkspace] openURL:launchableUrl
                             configuration:NSWorkspaceOpenConfiguration.configuration
                         completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if ( error ) {
            slog(@"Launch URL done. Error = [%@]", error);
        }
    }];
}

- (IBAction)onAppSettings:(id)sender {
    [AppSettingsWindowController.sharedInstance showGeneralTab];
}

- (void)clearAsyncUpdateIdsAndEphemeralOfflineFlags {
    for (MacDatabasePreferences* preferences in MacDatabasePreferences.allDatabases) {
        preferences.asyncUpdateId = nil;
        preferences.userRequestOfflineOpenEphemeralFlagForDocument = NO;
    }
}

- (void)startRefreshOtpTimer {

    
    if(self.timerRefreshOtp == nil) {
        self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(publishTotpUpdateNotification) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
    }
}

- (void)stopRefreshOtpTimer {
    slog(@"stopRefreshOtpTimer");
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (void)publishTotpUpdateNotification {
    [NSNotificationCenter.defaultCenter postNotificationName:kTotpUpdateNotification object:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return !Settings.sharedInstance.showSystemTrayIcon && Settings.sharedInstance.quitStrongboxOnAllWindowsClosed;
}

- (IBAction)onDumpXml:(id)sender {
    NSOpenPanel* openPanel = NSOpenPanel.openPanel;
    if ( [openPanel runModal] == NSModalResponseOK ) {
        NSData* data = [NSData dataWithContentsOfURL:openPanel.URL];
        
        MacAlerts *a = [[MacAlerts alloc] init];
        NSString* password = [a input:@"Password" defaultValue:@"" allowEmpty:YES];

        NSString* xml = [Serializator expressToXml:data password:password];
        
        slog(@"XML Dump: \n%@", xml);
    }
}

- (void)onProStatusChanged:(id)param {
    slog(@"✅ AppDelegate: Pro Status Changed!");

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self bindFreeOrProStatus];
    });
}

- (void)bindFreeOrProStatus {
    if ( MacCustomizationManager.isAProBundle || ProUpgradeIAPManager.sharedInstance.isLegacyLifetimeIAPPro ) { 
        [self removeMenuItem:kTopLevelMenuItemTagStrongbox action:@selector(onUpgradeToFullVersion:)];
    }
    
    if ( !MacCustomizationManager.supportsTipJar ) {
        [self removeMenuItem:kTopLevelMenuItemTagStrongbox action:@selector(onShowTipJar:)];
    }
    
    NSMenu* topLevelMenuItem = [NSApplication.sharedApplication.mainMenu itemWithTag:kTopLevelMenuItemTagStrongbox].submenu;
    if ( topLevelMenuItem ) {
        NSUInteger index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.action == @selector(onAbout:);
        }];

        if( index != NSNotFound) {
            NSMenuItem* menuItem = [topLevelMenuItem itemAtIndex:index];
            NSString* fmt = Settings.sharedInstance.isPro ? NSLocalizedString(@"prefs_vc_app_version_info_pro_fmt", @"About Strongbox Pro %@") : NSLocalizedString(@"prefs_vc_app_version_info_none_pro_fmt", @"About Strongbox %@");
            menuItem.title = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
        }
        
        index = [topLevelMenuItem.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return obj.action == @selector(onUpgradeToFullVersion:);
        }];

        if( index != NSNotFound) {
            NSMenuItem* menuItem = [topLevelMenuItem itemAtIndex:index];
            NSString* fmt = Settings.sharedInstance.isPro ? NSLocalizedString(@"upgrade_vc_change_my_license", @"Change My License...") : NSLocalizedString(@"mac_upgrade_button_title", @"Upgrade");
            menuItem.title = [NSString stringWithFormat:fmt, [Utils getAppVersion]];
        }
    }
    
    [self startOrStopSSHAgent];
    
    [self startOrStopAutoFillProxyServer];
}



- (IBAction)onRecoverKeyFile:(id)sender {
    __weak AppDelegate* weakSelf = self;
    
    [SwiftUIViewFactory showKeyFileRecoveryScreen:^(KeyFile * _Nonnull keyFile) {
        [weakSelf onSaveKeyFile:keyFile];
    }];
}

- (IBAction)onGenerateKeyFile:(id)sender {    
    __weak AppDelegate* weakSelf = self;
    
    KeyFile* keyFile = [KeyFileManagement generateNewV2];
    
    [SwiftUIViewFactory showKeyFileGeneratorScreenWithKeyFile:keyFile
                                                      onPrint:^{
        [weakSelf onPrintKeyFileRecoverySheet:keyFile];
    } onSave:^BOOL{
        return [weakSelf onSaveKeyFile:keyFile];
    }];
}

- (BOOL)onSaveKeyFile:(KeyFile*)keyFile {
    NSSavePanel* panel = NSSavePanel.savePanel;
    panel.nameFieldStringValue = @"keyfile.keyx";
    
    
    [panel setTitle:NSLocalizedString(@"new_key_file_save_key_file", @"Save Key File")];
    
    NSInteger result = [panel runModal];
    if ( result == NSModalResponseOK ) {
        if ( panel.URL ) {
            NSData* data = [keyFile.xml dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
            
            if ( !data ) {
                [DBManagerPanel.sharedInstance show];
                
                [MacAlerts error:[Utils createNSError:@"Could not get xml data!" errorCode:123]
                          window:DBManagerPanel.sharedInstance.contentViewController.view.window];
                
                return NO;
            }
            
            NSError* error;
            if ( ![data writeToURL:panel.URL options:kNilOptions error:&error] ) {
                [DBManagerPanel.sharedInstance show];
                
                [MacAlerts error:error window:DBManagerPanel.sharedInstance.contentViewController.view.window];
                
                return NO;
            }
            else {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)onPrintKeyFileRecoverySheet:(KeyFile*)keyFile {
    [keyFile printRecoverySheet];
}

#ifndef NO_NETWORKING
- (void)maybeWarnAboutCloudKitUnavailability {
    if ( CloudKitDatabasesInteractor.shared.fastIsAvailable ) {
        Settings.sharedInstance.hasWarnedAboutCloudKitUnavailability = NO;
    }
    else {
        BOOL hasCloudKitDbs = [MacDatabasePreferences.allDatabases anyMatch:^BOOL(MacDatabasePreferences * _Nonnull obj) {
            return obj.storageProvider == kCloudKit;
        }];
        
        if ( hasCloudKitDbs && !Settings.sharedInstance.hasWarnedAboutCloudKitUnavailability ) {
            Settings.sharedInstance.hasWarnedAboutCloudKitUnavailability = YES;
            
            [DBManagerPanel.sharedInstance show];
            
            [MacAlerts info:NSLocalizedString(@"strongbox_sync_unavailable_title", @"Strongbox Sync Unavailable")
            informativeText:NSLocalizedString(@"strongbox_sync_unavailable_msg", @"Strongbox Sync has become unavailable. Please check you are signed in to your Apple account in System Settings.")
                     window:DBManagerPanel.sharedInstance.window
                 completion:nil];
        }
    }
}
#endif

- (IBAction)onShowPasswordGenerator:(id)sender {
    [PasswordGenerator.sharedInstance show];
}

- (IBAction)onSftpConnectionsManager:(id)sender {
#ifndef NO_NETWORKING
    [DBManagerPanel.sharedInstance show];
    
    SFTPConnectionsManager* vc = [SFTPConnectionsManager instantiateFromStoryboard];
    vc.manageMode = YES;
        
    [DBManagerPanel.sharedInstance.contentViewController presentViewControllerAsSheet:vc];
#endif
}

- (IBAction)onWebDAVConnectionsManager:(id)sender {
#ifndef NO_NETWORKING
    [DBManagerPanel.sharedInstance show];
    
    WebDAVConnectionsManager* vc = [WebDAVConnectionsManager instantiateFromStoryboard];
    vc.manageMode = YES;

    [DBManagerPanel.sharedInstance.contentViewController presentViewControllerAsSheet:vc];
#endif
}

- (void)showQuickSearchPalette:(id)sender {
    [QuickSearchPalette.shared toggleShow];
}

- (void)onTrayShowViewDatabases:(id)sender {
    __weak AppDelegate* weakSelf = self;
    
    [self showAndActivateStrongbox:nil suppressEmptyLaunchBehaviour:YES suppressWindowUnminimization:YES completion:^{
        [weakSelf onViewDatabases:nil];
    }];
}

- (void)onTrayShowAppSettings:(id)sender {
    __weak AppDelegate* weakSelf = self;
    
    [self showAndActivateStrongbox:nil suppressEmptyLaunchBehaviour:YES suppressWindowUnminimization:YES completion:^{
        [weakSelf onAppSettings:nil];
    }];
}

- (void)onTrayShowPasswordGenerator:(id)sender {
    __weak AppDelegate* weakSelf = self;
    
    [self showAndActivateStrongbox:nil suppressEmptyLaunchBehaviour:YES suppressWindowUnminimization:YES completion:^{
        [weakSelf onShowPasswordGenerator:nil];
    }];
}



- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *URLString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:URLString];
    
    slog(@"🐞 handleGetURLEvent: [%@]", URLString);
    
    if ( [url.absoluteString.lowercaseString hasPrefix:@"otpauth"]) {
        [self beginImport2FACodeOtpAuthUrl:url];
    }
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    else if ( [url.absoluteString hasPrefix:@"com.googleusercontent.apps"] ) {
        [GoogleDriveManager.sharedInstance handleUrl:url];

    }
    else if ([url.absoluteString hasPrefix:@"db"]) {
        [DropboxV2StorageProvider.sharedInstance handleAuthRedirectUrl:url];
        [NSRunningApplication.currentApplication activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
    }
#endif
}

- (void)beginImport2FACodeOtpAuthUrl:(NSURL*)url {
    [DBManagerPanel.sharedInstance show];
    NSViewController* viewController = DBManagerPanel.sharedInstance.contentViewController;
    
    OTPToken* token = [OTPToken tokenWithURL:url];
    
    if ( !token ) {
        slog(@"🔴 Could not parse OTPAuth url [%@]", url);
        [MacAlerts info:@"This is not a valid OTPAuth URL" window:viewController.view.window];
        return;
    }
    
    [self beginImport2FACodeWithToken:token viewController:viewController];
}

- (void)beginImport2FACodeWithToken:(OTPToken*)token viewController:(NSViewController*)viewController {
    NSArray<MacDatabasePreferences*>* writeableDbs = [MacDatabasePreferences.allDatabases filter:^BOOL(MacDatabasePreferences * _Nonnull obj) {
        return !obj.readOnly;
    }];
    
    if ( writeableDbs.count == 0 ) {
        slog(@"🔴 No writeable databases available!");
        [MacAlerts info:@"No Writeable Databases Found" window:viewController.view.window];
        return;
    }
    
    if ( MacDatabasePreferences.allDatabases.count > 1 ) {
        [self selectDatabaseFor2FAImport:token viewController:viewController];
    } else {
        [self beginImport2FAIntoDatabase:MacDatabasePreferences.allDatabases.firstObject token:token viewController:viewController];
    }
}

- (void)selectDatabaseFor2FAImport:(OTPToken*)token viewController:(NSViewController*)viewController {
    SelectDatabaseViewController* selectDbVc = [SelectDatabaseViewController fromStoryboard];
    
    selectDbVc.unlockedDatabases = [[DatabasesCollection.shared getUnlockedDatabases] map:^id _Nonnull(Model * _Nonnull obj, NSUInteger idx) {
        return obj.databaseUuid;
    }].set;
    
    selectDbVc.disableReadOnlyDatabases = YES;
    selectDbVc.customTitle = NSLocalizedString(@"select_database_to_save_2fa_code_title", @"Select Database for 2FA Code");
    
    __weak AppDelegate* weakSelf = self;
    selectDbVc.onDone = ^(BOOL userCancelled, MacDatabasePreferences * _Nonnull database) {
        if (!userCancelled) {
            [weakSelf beginImport2FAIntoDatabase:database token:token viewController:viewController];
        }
    };

    [viewController presentViewControllerAsSheet:selectDbVc];
}

- (void)beginImport2FAIntoDatabase:(MacDatabasePreferences*)database token:(OTPToken*)token viewController:(NSViewController*)viewController {
    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:database.uuid];
    
    if ( model ) {
        [self import2FAIntoUnlockedDatabase:model token:token viewController:viewController];
    }
    else {
        __weak AppDelegate* weakSelf = self;
        [DatabasesCollection.shared initiateDatabaseUnlockWithUuid:database.uuid
                                                   syncAfterUnlock:YES
                                                           message:nil
                                                        completion:^(BOOL success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( success ) {
                    [weakSelf beginImport2FAIntoDatabase:database token:token viewController:viewController]; 
                }
                else {
                    [MacAlerts yesNo:NSLocalizedString(@"unlock_was_unsuccessful", @"Unlock Unsuccessful")
                     informativeText:NSLocalizedString(@"generic_would_you_like_to_try_again", @"Would you like to try again?")
                              window:viewController.view.window
                          completion:^(BOOL yesNo) {
                        if ( yesNo ) {
                            [weakSelf beginImport2FACodeWithToken:token viewController:viewController];
                        }
                    }];
                }
            });
        }];
    }
}

- (void)import2FAIntoUnlockedDatabase:(Model*)model token:(OTPToken*)token viewController:(NSViewController*)viewController {
    Document* doc = [DatabasesCollection.shared documentForDatabaseWithUuid:model.databaseUuid];
    if ( doc ) {
        [self import2FAWithDocument:doc token:token viewController:viewController];
    }
    else {
        __weak AppDelegate* weakSelf = self;
        [DatabasesCollection.shared showDatabaseDocumentWindowWithUuid:model.databaseUuid
                                                            completion:^(Document * _Nullable document, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( error ) {
                    [MacAlerts error:error window:viewController.view.window];
                }
                else {
                    [weakSelf import2FAWithDocument:document token:token viewController:viewController];
                }
            });
        }];
    }
}

- (void)import2FAWithDocument:(Document*)document token:(OTPToken*)token viewController:(NSViewController*)viewController {
    if ( document.isDisplayingEditSheet ) {
        [MacAlerts info:NSLocalizedString(@"generic_edit_in_progress", @"Edit In Progress")
        informativeText:NSLocalizedString(@"generic_edit_in_progress_2fa_code", @"There is an edit in progress, please complete this before adding a 2FA Code.")
                 window:viewController.view.window
             completion:nil];
    }
    else {
        [document import2FAToken:token];
    }
}



- (void)checkIfBiometricsDatabaseChanged {
    BOOL bioDbHasChanged = [BiometricIdHelper.sharedInstance isBiometricDatabaseStateHasChanged:NO];
    if ( bioDbHasChanged ) {
        [self clearBioDbAndMessageUser];
    }
}

- (void)clearBioDbAndMessageUser {
    [DatabasesCollection.shared tryToLockAll];
    
    [self clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState];
    
    [DBManagerPanel.sharedInstance show];
    NSViewController* viewController = DBManagerPanel.sharedInstance.contentViewController;

    dispatch_async(dispatch_get_main_queue(), ^{
        [MacAlerts info:NSLocalizedString(@"open_sequence_warn_biometrics_db_changed_title", @"Biometrics Database Changed")
        informativeText:NSLocalizedString(@"open_sequence_warn_biometrics_db_changed_message", @"It looks like your biometrics database has changed, probably because you added a new face or fingerprint. Strongbox now requires you to re-enter your master credentials manually for security reasons.")
                 window:viewController.view.window
             completion:nil];
    });
}

- (void)clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState {
    NSArray<MacDatabasePreferences*>* databases = MacDatabasePreferences.allDatabases;
    
    
    
    
    
    for (MacDatabasePreferences* database in databases) {
        if( database.isConvenienceUnlockEnabled ) {
            slog(@"Clearing Biometrics for Database: [%@]", database.nickName);
            
            database.conveniencePasswordHasBeenStored = NO; 
            database.convenienceMasterPassword = nil;
        }
    }
    
    [BiometricIdHelper.sharedInstance clearBiometricRecordedDatabaseState];
}

@end
