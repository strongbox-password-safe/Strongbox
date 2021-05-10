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
#import "DatabasesManager.h"

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

@property (weak) IBOutlet NSTextField *textFieldStorage;

@property NSClickGestureRecognizer *gestureRecognizerClick;
@property NSString* uuid;
@property NSString* originalNickName;

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
}

- (void)setWithDatabase:(DatabaseMetadata*)metadata {
    [self setWithDatabase:metadata autoFill:NO wormholeUnlocked:NO];
}

- (void)setWithDatabase:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill wormholeUnlocked:(BOOL)wormholeUnlocked {
    self.uuid = metadata.uuid;
    self.originalNickName = metadata.nickName;
    
    self.gestureRecognizerClick.enabled = !autoFill;
    
    self.textFieldName.stringValue = @"";
    self.textFieldSubtitleLeft.stringValue = @"";
    self.textFieldSubtitleTopRight.stringValue = @"";
    self.textFieldSubtitleBottomRight.stringValue = @"";
    self.textFieldStorage.stringValue = @"";
    
    self.imageViewQuickLaunch.hidden = YES;
    self.imageViewOutstandingUpdate.hidden = YES;
    self.imageViewReadOnly.hidden = YES;
    
    self.imageViewSyncing.hidden = YES;
    self.syncProgressIndicator.hidden = YES;
    [self.syncProgressIndicator stopAnimation:nil];
    
    self.imageViewUnlocked.hidden = !wormholeUnlocked;
    
    @try {
        [self determineFields:metadata autoFill:autoFill];
    
        self.imageViewQuickLaunch.hidden = !metadata.launchAtStartup;
        self.imageViewOutstandingUpdate.hidden = metadata.outstandingUpdateId == nil;
        
        SyncOperationState syncState = autoFill ? kSyncOperationStateInitial : [MacSyncManager.sharedInstance getSyncStatus:metadata].state;
        
        if (syncState == kSyncOperationStateInProgress ||
            syncState == kSyncOperationStateError ||
            syncState == kSyncOperationStateBackgroundButUserInteractionRequired ) { 
            
            self.imageViewSyncing.hidden = NO;
            self.imageViewSyncing.image = syncState == kSyncOperationStateError ? [NSImage imageNamed:@"error"] : [NSImage imageNamed:@"syncronize"];
            
            if (@available(macOS 10.14, *)) {
                NSColor *tint = (syncState == kSyncOperationStateInProgress ? NSColor.systemBlueColor : NSColor.systemOrangeColor);
                self.imageViewSyncing.contentTintColor = tint;
            }
            
            if ( syncState == kSyncOperationStateInProgress ) {
                self.syncProgressIndicator.hidden = NO;
                [self.syncProgressIndicator startAnimation:nil];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception getting display attributes for database: %@", exception);
    }
}

- (void)determineFields:(DatabaseMetadata*)metadata autoFill:(BOOL)autoFill {
    NSString* path = @"";
    NSString* fileSize = @"";
    NSString* fileMod = @"";

    
    NSString* title = metadata.nickName ? metadata.nickName : @"";
    
    if ( ![metadata.fileUrl.scheme isEqualToString:kStrongboxFileUrlScheme] && ![metadata.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        NSURLComponents *comp = [[NSURLComponents alloc] init];

        comp.host = metadata.fileUrl.host;
        path = [NSString stringWithFormat:@"%@ (%@)", metadata.fileUrl.lastPathComponent, metadata.fileUrl.host];
    
        NSDate* modDate;
        unsigned long long size;
        NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache:metadata modified:&modDate fileSize:&size];
        
        if ( workingCopy ) {
            fileSize = friendlyFileSizeString(size);
            fileMod = modDate.friendlyDateTimeStringPrecise;
        }
    }
    else {
        
        
        
        
        
        
        NSURL* url;
        
        if ( [metadata.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
            url = fileUrlFromManagedUrl(metadata.fileUrl);
        }
        else {
            url = metadata.fileUrl;
        }
        
        if ( url ) {
            if ( [NSFileManager.defaultManager isUbiquitousItemAtURL:url] ) {
                path = [self getFriendlyICloudPath:url.path];
            }
            else {
                path = [self getPathRelativeToUserHome:url.path];
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
    }
    
    self.textFieldName.stringValue = title;
    self.textFieldSubtitleLeft.stringValue = path;
    self.textFieldSubtitleTopRight.stringValue = fileSize;
    self.textFieldSubtitleBottomRight.stringValue = fileMod;
    self.textFieldStorage.stringValue = [SafeStorageProviderFactory getStorageDisplayName:metadata];
}

- (NSString*)getPathRelativeToUserHome:(NSString*)path {
    NSString* userHome = FileManager.sharedInstance.userHomePath;
    
    if ( userHome && path.length > userHome.length ) {
        path = [path stringByReplacingOccurrencesOfString:userHome withString:@"~" options:kNilOptions range:NSMakeRange(0, userHome.length)];
    }
    
    return path;
}

- (NSString*)getFriendlyICloudPath:(NSString*)path {
    NSURL* iCloudRoot = FileManager.sharedInstance.iCloudRootURL;
    NSURL* iCloudDriveRoot = FileManager.sharedInstance.iCloudDriveRootURL;

    
    
    if ( iCloudRoot && path.length > iCloudRoot.path.length && [[path substringToIndex:iCloudRoot.path.length] isEqualToString:iCloudRoot.path]) {
        return [NSString stringWithFormat:@"%@ (%@)", path.lastPathComponent, NSLocalizedString(@"databases_vc_database_location_suffix_database_is_in_official_icloud_strongbox_folder", @"Strongbox iCloud")];
    }
    
    
    
    if ( iCloudDriveRoot && path.length > iCloudDriveRoot.path.length && [[path substringToIndex:iCloudDriveRoot.path.length] isEqualToString:iCloudDriveRoot.path]) {
        NSArray *iCloudDriveDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:iCloudDriveRoot.path];
        NSArray *pathDisplayComponents = [NSFileManager.defaultManager componentsToDisplayForPath:path];

        if ( pathDisplayComponents.count > iCloudDriveDisplayComponents.count ) {
            NSArray* relative = [pathDisplayComponents subarrayWithRange:NSMakeRange(iCloudDriveDisplayComponents.count, pathDisplayComponents.count - iCloudDriveDisplayComponents.count)];
            
            if ( relative.count > 1 ) {
                NSString* niceICloudDriveName = relative.firstObject;
                NSArray* pathWithiniCloudDrive = [relative subarrayWithRange:NSMakeRange(1, relative.count-1)];
                NSString* strPathWithiniCloudDrive = [pathWithiniCloudDrive componentsJoinedByString:@"/"];
                return [NSString stringWithFormat:@"%@ (%@)", strPathWithiniCloudDrive, niceICloudDriveName];
            }
        }
    }

    return [self getPathRelativeToUserHome:path];
}

- (void)onNicknameClick {

    
    if ( self.textFieldName.isEditable ) {
        NSLog(@"Ignoring onNicknameClick - because isEditable");
        return;
    }
    
    [self beginEditingNickname];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    NSLog(@"controlTextDidChange!");
    
    if ( obj.object == self.textFieldName ) {
        NSString* raw = self.textFieldName.stringValue;
        NSString* trimmed = [DatabasesManager trimDatabaseNickName:raw];
        
        if ( [self.originalNickName isEqualToString:trimmed] || ( [DatabasesManager.sharedInstance isValid:trimmed] && [DatabasesManager.sharedInstance isUnique:trimmed] )) {
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
    NSString* trimmed = [DatabasesManager trimDatabaseNickName:raw];

    if ( ![self.originalNickName isEqualToString:trimmed] && [DatabasesManager.sharedInstance isValid:trimmed] && [DatabasesManager.sharedInstance isUnique:trimmed] ) {
        DatabaseMetadata* metadata = [DatabasesManager.sharedInstance getDatabaseById:self.uuid];
        metadata.nickName = trimmed;
        [DatabasesManager.sharedInstance update:metadata];
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
