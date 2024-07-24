//
//  AppDelegate.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern const NSInteger kTopLevelMenuItemTagStrongbox;
extern const NSInteger kTopLevelMenuItemTagFile;
extern const NSInteger kTopLevelMenuItemTagView;

extern NSString* _Nonnull const kUpdateNotificationQuickRevealStateChanged;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)onUpgradeToFullVersion:(id _Nullable )sender;



- (void)clearClipboardWhereAppropriate;
- (void)onStrongboxDidChangeClipboard; 

@property BOOL suppressQuickLaunchForNextAppActivation; 

@property (readonly) BOOL isWasLaunchedAsLoginItem;



- (void)cancelAutoLockTimer;
- (void)startAutoLockTimer;

- (void)showAndActivateStrongbox:(NSString*_Nullable)databaseUuid completion:(void (^_Nullable)(void))completion;

@end

