//
//  DatabaseCellView.m
//  MacBox
//
//  Created by Strongbox on 18/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseCellView.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "NSDate+Extensions.h"
#import "MacUrlSchemes.h"
#import "WorkingCopyManager.h"
#import "FileManager.h"
#import "Settings.h"
#import "MacSyncManager.h"
#import <QuartzCore/QuartzCore.h>
#import "SafeStorageProviderFactory.h"
#import "SFTPStorageProvider.h"
#import "WebDAVStorageProvider.h"

@interface DatabaseCellView () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *textFieldName;

@property (weak) IBOutlet NSTextField *textFieldSubtitleLeft;
@property (weak) IBOutlet NSTextField *textFieldSubtitleTopRight;
@property (weak) IBOutlet NSTextField *textFieldSubtitleBottomRight;



@property (weak) IBOutlet NSImageView *imageViewQuickLaunch;
@property (weak) IBOutlet NSImageView *imageViewOutstandingUpdate;
@property (weak) IBOutlet NSImageView *imageViewReadOnly;
@property (weak) IBOutlet NSImageView *imageViewSyncing;
@property (weak) IBOutlet NSProgressIndicator *syncProgressIndicator;
@property (weak) IBOutlet NSImageView *imageViewUnlocked;

@property NSClickGestureRecognizer *gestureRecognizerClick;
@property NSString* uuid;
@property NSString* originalNickName;

@property (weak) IBOutlet NSImageView *imageViewProvider;

@end

@implementation DatabaseCellView

- (void)awakeFromNib {
    [super awakeFromNib];
        
    self.textFieldName.delegate = self;
    
    self.gestureRecognizerClick = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(onNicknameClick)];
    [self.textFieldName addGestureRecognizer:self.gestureRecognizerClick];
    
    if (@available(macOS 11.0, *)) {
        self.imageViewUnlocked.image = [NSImage imageWithSystemSymbolName:@"lock.open.fill" accessibilityDescription:nil];
        self.imageViewUnlocked.contentTintColor = NSColor.systemGreenColor;
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    self.uuid = nil;
    self.originalNickName = nil;
    self.alphaValue = 1.0f;
    
    self.imageView.contentTintColor = nil;
}

- (void)setWithDatabase:(MacDatabasePreferences*)metadata {
    [self setWithDatabase:metadata
 nickNameEditClickEnabled:YES
            showSyncState:YES
 indicateAutoFillDisabled:NO
         wormholeUnlocked:NO
                 disabled:NO];
}

- (void)setWithDatabase:(MacDatabasePreferences *)metadata
nickNameEditClickEnabled:(BOOL)nickNameEditClickEnabled
          showSyncState:(BOOL)showSyncState
indicateAutoFillDisabled:(BOOL)indicateAutoFillDisabled
       wormholeUnlocked:(BOOL)wormholeUnlocked
               disabled:(BOOL)disabled {
    [self resetUi:metadata];
    
    self.gestureRecognizerClick.enabled = nickNameEditClickEnabled;
    self.imageViewUnlocked.hidden = !wormholeUnlocked;
    
    @try {
        self.imageViewProvider.image = [SafeStorageProviderFactory getImageForProvider:metadata.storageProvider];

        [self bindTextFields:metadata];
    
        [self bindEnableDisabled:metadata disabled:disabled indicateAutoFillDisabled:indicateAutoFillDisabled];

        [self bindIndicators:metadata];
        
        [self bindSyncState:metadata showSyncState:showSyncState];
    }
    @catch (NSException *exception) {
        NSLog(@"Exception getting display attributes for database: %@", exception);
    }
}

- (void)resetUi:(MacDatabasePreferences*)metadata {
    self.uuid = metadata.uuid;
    self.originalNickName = metadata.nickName;
    self.textFieldName.stringValue = @"";
    self.textFieldSubtitleLeft.stringValue = @"";
    self.textFieldSubtitleTopRight.stringValue = @"";
    self.textFieldSubtitleBottomRight.stringValue = @"";
    self.imageViewQuickLaunch.hidden = YES;
    self.imageViewOutstandingUpdate.hidden = YES;
    self.imageViewReadOnly.hidden = YES;
    self.imageViewSyncing.hidden = YES;
    self.syncProgressIndicator.hidden = YES;
    [self.syncProgressIndicator stopAnimation:nil];
}

- (void)bindIndicators:(MacDatabasePreferences*)metadata {
    self.imageViewQuickLaunch.hidden = !metadata.launchAtStartup;
    self.imageViewOutstandingUpdate.hidden = metadata.outstandingUpdateId == nil;
    self.imageViewReadOnly.hidden = !metadata.readOnly;
}

- (void)bindEnableDisabled:(MacDatabasePreferences*)metadata disabled:(BOOL)disabled indicateAutoFillDisabled:(BOOL)indicateAutoFillDisabled {
    if ( disabled || ( indicateAutoFillDisabled && !metadata.autoFillEnabled ) ) {
        if ( indicateAutoFillDisabled && !metadata.autoFillEnabled ) {
            self.textFieldSubtitleLeft.stringValue = NSLocalizedString(@"db_management_disable_done", @"AutoFill Disabled");
        }
        
        self.imageViewProvider.image = [NSImage imageNamed:@"cancel"];
        self.imageViewProvider.contentTintColor = NSColor.secondaryLabelColor;
        
        self.alphaValue = 0.75f;
    }
}

- (void)bindTextFields:(MacDatabasePreferences*)metadata {
    if ( ![metadata.fileUrl.scheme isEqualToString:kStrongboxFileUrlScheme] && ![metadata.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        [self bindTextFieldsForNoneFileDatabase:metadata];
    }
    else {
        [self bindTextFieldsForFileDatabase:metadata];
    }
}

- (void)bindTextFieldsForFileDatabase:(MacDatabasePreferences*)metadata {
    NSString* path = @"";
    NSString* fileSize = @"";
    NSString* fileMod = @"";
    NSString* title = metadata.nickName ? metadata.nickName : @"";

    
    
    
    
    
    
    NSURL* url;
    
    if ( [metadata.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        url = fileUrlFromManagedUrl(metadata.fileUrl);
    }
    else {
        url = metadata.fileUrl;
    }
    
    if ( url ) {
        if ( [NSFileManager.defaultManager isUbiquitousItemAtURL:url] ) {
            path = getFriendlyICloudPath(url.path);
            self.imageViewProvider.image = [SafeStorageProviderFactory getImageForProvider:kiCloud];
        }
        else {
            path = [NSString stringWithFormat:@"%@ (%@)", getPathRelativeToUserHome(url.path), [SafeStorageProviderFactory getStorageDisplayNameForProvider:metadata.storageProvider]];
        }
        
        NSError* error;
        NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
        if (error) {
            NSLog(@"Error getting attributes of database file: [%@]", error);
            path = [NSString stringWithFormat:@"(%ld) %@", (long)error.code, error.localizedDescription];
        }
        else {
            fileSize = friendlyFileSizeString(attr.fileSize);
            fileMod = attr.fileModificationDate.friendlyDateTimeStringPrecise;
        }
    }

    self.textFieldName.stringValue = title;
    self.textFieldSubtitleLeft.stringValue = path;
    self.textFieldSubtitleTopRight.stringValue = fileSize;
    self.textFieldSubtitleBottomRight.stringValue = fileMod;
}

- (void)bindTextFieldsForNoneFileDatabase:(MacDatabasePreferences*)metadata {
    NSString* path = @"";
    NSString* fileSize = @"";
    NSString* fileMod = @"";
    NSString* title = metadata.nickName ? metadata.nickName : @"";

    if ( metadata.storageProvider == kSFTP ) {
        SFTPSessionConfiguration* connection = [SFTPStorageProvider.sharedInstance getConnectionFromDatabase:metadata];
        
        path = [NSString stringWithFormat:@"%@ (%@)", metadata.fileUrl.lastPathComponent, connection.name.length ? connection.name : connection.host];
    }
    else if ( metadata.storageProvider == kWebDAV ) {
        WebDAVSessionConfiguration* connection = [WebDAVStorageProvider.sharedInstance getConnectionFromDatabase:metadata];
        
        path = [NSString stringWithFormat:@"%@ (%@)", metadata.fileUrl.lastPathComponent, connection.name.length ? connection.name : connection.host];
    }
    else {
        path = [NSString stringWithFormat:@"%@ (%@)", metadata.fileUrl.lastPathComponent, [SafeStorageProviderFactory getStorageDisplayNameForProvider:metadata.storageProvider] ];
    }
    
    NSDate* modDate;
    unsigned long long size;
    NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache:metadata.uuid
                                                                         modified:&modDate
                                                                         fileSize:&size];
    
    if ( workingCopy ) {
        fileSize = friendlyFileSizeString(size);
        fileMod = modDate.friendlyDateTimeStringPrecise;
    }
    
    self.textFieldName.stringValue = title;
    self.textFieldSubtitleLeft.stringValue = path;
    self.textFieldSubtitleTopRight.stringValue = fileSize;
    self.textFieldSubtitleBottomRight.stringValue = fileMod;
}

- (void)bindSyncState:(MacDatabasePreferences *)metadata showSyncState:(BOOL)showSyncState {
    SyncOperationState syncState = showSyncState ? [MacSyncManager.sharedInstance getSyncStatus:metadata].state : kSyncOperationStateInitial;
    
    if (syncState == kSyncOperationStateInProgress ||
        syncState == kSyncOperationStateError ||
        syncState == kSyncOperationStateBackgroundButUserInteractionRequired ) { 
        
        self.imageViewSyncing.hidden = NO;
        self.imageViewSyncing.image = syncState == kSyncOperationStateError ? [NSImage imageNamed:@"error"] : [NSImage imageNamed:@"syncronize"];
        
        NSColor *tint = (syncState == kSyncOperationStateInProgress ? NSColor.systemBlueColor : NSColor.systemOrangeColor);
        self.imageViewSyncing.contentTintColor = tint;

        if ( syncState == kSyncOperationStateInProgress ) {
            self.syncProgressIndicator.hidden = NO;
            [self.syncProgressIndicator startAnimation:nil];
        }
    }
    else if ( metadata.asyncUpdateId != nil ) {
        self.imageViewSyncing.hidden = NO;
        
        self.imageViewSyncing.image = [NSImage imageNamed:@"syncronize"];
        
        if (@available(macOS 11.0, *)) {
            self.imageViewSyncing.image = [NSImage imageWithSystemSymbolName:@"function" accessibilityDescription:nil];
            self.imageViewSyncing.controlSize = NSControlSizeLarge;
        }

        NSColor *tint = NSColor.systemYellowColor;
        self.imageViewSyncing.contentTintColor = tint;

        self.syncProgressIndicator.hidden = NO;
        [self.syncProgressIndicator startAnimation:nil];
    }
}

- (void)onChangeNickname {
    [self onNicknameClick];
}

- (void)onNicknameClick {

    
    if ( self.textFieldName.isEditable ) {
        NSLog(@"Ignoring onNicknameClick - because isEditable");
        return;
    }
    
    [self beginEditingNickname];
}

- (void)controlTextDidChange:(NSNotification *)obj {

    
    if ( obj.object == self.textFieldName ) {
        NSString* raw = self.textFieldName.stringValue;
        NSString* trimmed = [MacDatabasePreferences trimDatabaseNickName:raw];
        
        if ( [self.originalNickName isEqualToString:trimmed] || ( [MacDatabasePreferences isValid:trimmed] && [MacDatabasePreferences isUnique:trimmed] )) {
            self.textFieldName.textColor = NSColor.labelColor;
        }
        else {
            self.textFieldName.textColor = NSColor.systemOrangeColor;
        }
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {

 
    [self endEditingNickname];
    [self setNewNicknameIfValidOtherwiseRestore];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSLog(@"%@-%@-%@", control, textView, NSStringFromSelector(commandSelector));

    if (commandSelector == NSSelectorFromString(@"insertNewline:")) { 
        [self endEditingNickname];
        [self setNewNicknameIfValidOtherwiseRestore];
    }
    else if (commandSelector == NSSelectorFromString(@"cancelOperation:")) { 
        [self endEditingNickname];
        [self restoreOriginalNickname];
    }
    
    return NO;
}

- (void)setNewNicknameIfValidOtherwiseRestore {
    NSString* raw = self.textFieldName.stringValue;
    NSString* trimmed = [MacDatabasePreferences trimDatabaseNickName:raw];

    if ( ![self.originalNickName isEqualToString:trimmed] &&
        [MacDatabasePreferences isValid:trimmed] &&
        [MacDatabasePreferences isUnique:trimmed] ) {
        
        [MacDatabasePreferences fromUuid:self.uuid].nickName = trimmed;
    }
    else {
        [self restoreOriginalNickname];
    }
}

- (void)beginEditingNickname {
    if ( self.onBeginEditingNickname ) {
        __weak DatabaseCellView* weakSelf = self;
        self.onBeginEditingNickname(weakSelf); 
    }
    
    self.textFieldName.editable = YES;
    [self.textFieldName becomeFirstResponder];
    
    NSRange range = self.textFieldName.currentEditor.selectedRange;
    [self.textFieldName.currentEditor setSelectedRange:NSMakeRange(range.length, 0)];
}

- (void)endEditingNickname {
    if ( self.onEndEditingNickname ) {
        __weak DatabaseCellView* weakSelf = self;
        self.onEndEditingNickname(weakSelf); 
    }
    
    self.textFieldName.textColor = NSColor.labelColor;
    self.textFieldName.editable = NO;
}

- (void)restoreOriginalNickname {
    self.textFieldName.stringValue = self.originalNickName;
}

@end
