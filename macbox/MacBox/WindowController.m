//
//  WindowController.m
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "WindowController.h"
#import "Settings.h"
#import "Document.h"
#import "LockScreenViewController.h"
#import "MacAlerts.h"
#import "DatabaseSettingsTabViewController.h"
#import "Csv.h"
#import "ClipboardManager.h"
#import "MBProgressHUD.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "OTPToken+Generation.h"
#import "AppDelegate.h"
#import "MacUrlSchemes.h"
#import "SafeStorageProviderFactory.h"
#import "MacKeePassHistoryViewController.h"
#import "DatabaseFormatIncompatibilityHelper.h"
#import "Constants.h"
#import "SelectPredefinedIconController.h"
#import <WebKit/WebKit.h>
#import "CreateDatabaseOrSetCredentialsWizard.h"
#import "macOSSpinnerUI.h"
#import "BiometricIdHelper.h"
#import "DatabaseOnboardingTabViewController.h"
#import "Serializator.h"
#import "DatabaseFormatIncompatibilityHelper.h"
#import "DatabaseMerger.h"

#ifndef NO_NETWORKING

#import "SFTPStorageProvider.h" 
#import "WebDAVStorageProvider.h"

#endif

#ifndef NO_FAVICON_LIBRARY

#import "FavIconDownloader.h"

#endif

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface WindowController () <NSWindowDelegate>

@property (strong, nonatomic) CreateDatabaseOrSetCredentialsWizard *changeMasterPassword;
@property (strong, nonatomic) SelectPredefinedIconController* selectPredefinedIconController; 
@property (readonly, nullable) ViewModel* viewModel;
@property (readonly) BOOL databaseIsLocked;

@end

@implementation WindowController

- (void)dealloc {
    slog(@"😎 DEALLOC [%@]", self);
}

static NSString* getFreeTrialSuffix(void) {
    if ( Settings.sharedInstance.isPro ) {
        return @"";
    }
    
    return NSLocalizedString(@"mac_free_trial_window_title_suffix", @" - (Pro Upgrade Available)");
}

- (NSArray *)getStatusSuffixii {
    Document* doc = (Document*)self.document;
    
    NSMutableArray* statusii = NSMutableArray.array;
    
    if ( doc.viewModel.isEffectivelyReadOnly ) {
        [statusii addObject:NSLocalizedString(@"databases_toggle_read_only_context_menu", @"Read-Only")];
    }
    
    BOOL offlineMode = doc.viewModel.isInOfflineMode || doc.viewModel.alwaysOpenOffline || doc.viewModel.databaseMetadata.userRequestOfflineOpenEphemeralFlagForDocument;
    
    if ( offlineMode ) {
        [statusii addObject:NSLocalizedString(@"browse_vc_pulldown_refresh_offline_title", @"Offline Mode")];
    }
    
    return statusii;
}

- (NSString*)getStatusSuffix {
    NSString* statusSuffix = @"";
    
    NSArray* statusii = [self getStatusSuffixii];
    
    if ( statusii.firstObject ) {
        NSString* statusiiStrings = [statusii componentsJoinedByString:@", "];
        statusSuffix = [NSString stringWithFormat:@" (%@)", statusiiStrings];
    }
    
    return statusSuffix;
}

- (void)synchronizeWindowTitleWithDocumentName {
    [super synchronizeWindowTitleWithDocumentName];
    
    [self updateNextGenWindowSubtitle];
}

- (void)updateNextGenWindowSubtitle {
    self.window.subtitle = [NSString stringWithFormat:@"%@%@", [self getStorageLocationSubtitle], [self getStatusSuffix]];
}

- (NSString*)getStorageLocationSubtitle {
    Document* doc = (Document*)self.document;
    MacDatabasePreferences* metadata = doc.viewModel.databaseMetadata;
    
    return [SafeStorageProviderFactory getStorageSubtitleForDatabaseWindow:metadata];
}

- (NSString*)windowTitleForDocumentDisplayName:(NSString *)displayName {
    NSString* freeTrialSuffix = getFreeTrialSuffix();
    
    Document* doc = (Document*)self.document;
    
    MacDatabasePreferences* metadata = doc.viewModel.databaseMetadata;
    
    return [NSString stringWithFormat:@"%@%@", metadata.nickName, freeTrialSuffix];
}

- (void)setDocument:(id)document {
    [super setDocument:document];
    
    if ( document ) {
        slog(@"WindowController::setDocument [%@] - [%@]", self.document, self.contentViewController);
        
        
        
        
        
        if ( self.contentViewController ) {
            if ( [self.contentViewController respondsToSelector:@selector(onDocumentLoaded)]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.contentViewController performSelector:@selector(onDocumentLoaded)];
                });
            }
            else {
                slog(@"🔴 Unknown Content View Controller in Set Document: [%@]", self.contentViewController.class);
            }
        }
        else {
            slog(@"🔴 WARNWARN: No Content View Controller");
        }
        
        
        
        
        Document* doc = (Document*)document;
        if ( doc.databaseMetadata ) {
            self.windowFrameAutosaveName = [NSString stringWithFormat:@"autosave-frame-%@", doc.databaseMetadata.uuid];
        }
    }
}

- (void)bindScreenCaptureAllowed {
    BOOL blocked = Settings.sharedInstance.screenCaptureBlocked;
    
    [self.window setSharingType:blocked ? NSWindowSharingNone : NSWindowSharingReadOnly];
}

- (void)changeContentView {
    slog(@"WindowController::changeContentView - isLocked = [%hhd]", self.databaseIsLocked);
    
    [self bindFloatWindowOnTop];
    
    [self bindScreenCaptureAllowed];
    
    NSViewController* vc;
    
    if ( self.databaseIsLocked ) {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        vc = [storyboard instantiateControllerWithIdentifier:@"LockScreen"];
    }
    else {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"NextGen" bundle:nil];
        vc = [storyboard instantiateControllerWithIdentifier:@"DatabaseViewerScreen"];
    }
    
    
    
    [vc.view setFrame:self.contentViewController.view.frame];
        
    self.contentViewController = vc;
        
    if ( [self.contentViewController respondsToSelector:@selector(onDocumentLoaded)]) {
        [self.contentViewController performSelector:@selector(onDocumentLoaded)];
    }
    
    if ( !self.databaseIsLocked ) {
        self.window.titlebarAppearsTransparent = NO;
        [self maybeOnboardDatabase];
    }
    else {
        self.window.titlebarAppearsTransparent = YES;
        self.window.toolbar = [[NSToolbar alloc] init];
    }
    
    [self listenToEventsOfInterest];
}

- (BOOL)databaseIsLocked {
    return self.viewModel.locked;
}

- (ViewModel *)viewModel {
    Document* doc = self.document;
    ViewModel* viewModel = doc ? doc.viewModel : nil;
    
    return viewModel;
}

- (MacDatabasePreferences*)databaseMetadata {
    return self.viewModel ? self.viewModel.databaseMetadata : nil;
}




- (Node*)getSingleSelectedItem {
    if ( self.viewModel.nextGenSelectedItems.count == 1 ) {
        NSUUID* uuid = self.viewModel.nextGenSelectedItems.firstObject;
        return uuid ? [self.viewModel getItemById:uuid] : nil;
    }
    
    return nil;
}

- (NSString*)getSideBarSelectedTag {
    if ( self.viewModel.nextGenNavigationContext == OGNavigationContextTags ) {
        return self.viewModel.nextGenNavigationContextSelectedTag;
    }
    
    return nil;
}

- (Node*)getSideBarSelectedItem {
    if ( self.viewModel.nextGenNavigationContext == OGNavigationContextRegularHierarchy ) {
        NSUUID* uuid = self.viewModel.nextGenNavigationContextSideBarSelectedGroup;
        return uuid ? [self.viewModel getItemById:uuid] : nil;
    }
    else if ( self.viewModel.nextGenNavigationContext == OGNavigationContextFavourites ) {
        NSUUID* uuid = self.viewModel.nextGenNavigationSelectedFavouriteId;
        return uuid ? [self.viewModel getItemById:uuid] : nil;
    }
    
    return nil;
}

- (NSArray<Node*>*)getSelectedItems {
    if ( !self.viewModel.locked ) {
        return [self.viewModel.nextGenSelectedItems map:^id _Nonnull(NSUUID * _Nonnull obj, NSUInteger idx) {
            return [self.viewModel getItemById:obj];
        }];
    }
    else {
        slog(@"🔴 getSelectedItems: Model is locked - cannot get selected items!");
        return @[];
    }
}

- (NSArray<Node*>*)getMinimalSelectedEntriesOnly2 {
    return [self getMinimalSelectedEntriesOnly2:NO];
}

- (NSArray<Node*>*)getMinimalSelectedEntriesOnly2:(BOOL)searchableOnly {
    NSArray<Node*>* items = [self getSelectedItems];
    
    return [self getMinimalRecursiveEntriesOnly2:items searchableOnly:searchableOnly];
}

- (NSArray<Node*>*)getMinimalRecursiveEntriesOnly2:(NSArray<Node*>*)items searchableOnly:(BOOL)searchableOnly {
    NSSet<Node*>* minimalItems = [self.viewModel getMinimalNodeSet:items];
    
    NSArray<Node*>* entries = [minimalItems.allObjects flatMap:^NSArray * _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSMutableArray* ret = NSMutableArray.array;
        
        if ( obj.isGroup ) {
            [ret addObjectsFromArray:obj.allChildRecords];
        }
        else {
            [ret addObject:obj];
        }
        
        return ret;
    }];

    if ( searchableOnly ) {
        return [entries filter:^BOOL(Node * _Nonnull obj) {
            return obj.isSearchable;
        }];
    }
    else {
        return entries;
    }
}



- (void)menuNeedsUpdate:(NSMenu *)menu {

    
    
    
    
    
    for (NSMenuItem *item in menu.itemArray) {
        if ( item.action == @selector(onAddTagToItemsParentDummyMenuAction:)) {
            [self populateAddTagToItemsSubMenu:item.submenu];
        }
        else if (item.action == @selector(onRemoveTagFromItemsParentDummyMenuAction:)) {
            [self populateRemoveTagFromItemsSubMenu:item.submenu];
        }
        else if ([item.identifier isEqualToString:@"copy-field-submenu-identifier"]) {
            [self populateCopyFieldSubMenu:item.submenu];
        }
    }
}

- (void)populateCopyFieldSubMenu:(NSMenu*)theMenu {
    
    
    NSInteger idxInsertAfter = [theMenu indexOfItemWithTag:24121224];
    NSInteger idxInsertBefore = [theMenu indexOfItemWithTag:24121225];
    
    for ( NSInteger idx = idxInsertAfter + 1; idx < idxInsertBefore; idx++ ) {
        [theMenu removeItemAtIndex:idxInsertAfter + 1];
    }
    
    
    
    Node* item = [self getSingleSelectedItem];
    if ( !item ) { 
        return;
    }
    
    NSArray<NSString*> *customFieldKeys = [item.fields.customFieldsNoEmail.allKeys filter:^BOOL(NSString * _Nonnull obj) {
        return ![NodeFields isTotpCustomFieldKey:obj];
    }];
    
    if ( customFieldKeys.count > 0 ) {
        if ( !self.viewModel.customSortOrderForFields ) {
            customFieldKeys = [customFieldKeys sortedArrayUsingComparator:finderStringComparator];
        }
        
        NSInteger i = 1;
        for ( NSString* customFieldKey in customFieldKeys ) {
            NSMenuItem* item  = [[NSMenuItem alloc] initWithTitle:customFieldKey
                                                           action:@selector(onCopyCustomField:)
                                                    keyEquivalent:@""];
            
            [theMenu insertItem:item atIndex:idxInsertAfter + i];
            i++;
        }
    }
}

- (void)populateAddTagToItemsSubMenu:(NSMenu*)theMenu {
    
    
    [theMenu removeAllItems];
    NSArray<Node*>* items = [self getSelectedItems];
    
    BOOL isKeePass2 = self.viewModel && !self.viewModel.locked && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    
    if ( isKeePass2 && !self.viewModel.isEffectivelyReadOnly && items.count ) {
        
        
        NSMutableSet* inter = nil;
        for ( Node* item in items ) {
            if ( inter == nil ) {
                inter = item.fields.tags.mutableCopy;
            }
            else {
                [inter intersectSet:item.fields.tags];
            }
        }
        
        NSMutableSet* withCommonRemoved = self.viewModel.tagSet.mutableCopy;
        [withCommonRemoved minusSet:inter];
        
        [withCommonRemoved removeObject:kCanonicalFavouriteTag];
        
        
        
        NSArray<NSString*>* sortedTags = [withCommonRemoved.allObjects sortedArrayUsingComparator:finderStringComparator];
        for (NSString* tag in sortedTags ) {
            NSMenuItem* item  = [[NSMenuItem alloc] initWithTitle:tag action:@selector(onAddTagToItems:) keyEquivalent:@""];
            item.image = [NSImage imageWithSystemSymbolName:@"tag" accessibilityDescription:nil];
            [theMenu addItem:item];
        }
        
        [theMenu addItem:NSMenuItem.separatorItem];
        
        NSMenuItem* item  = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"new_tag_ellipsis", @"New Tag...") action:@selector(onAddNewTagToItems:) keyEquivalent:@""];
        [theMenu addItem:item];
    }
}

- (void)populateRemoveTagFromItemsSubMenu:(NSMenu*)theMenu {
    
    
    [theMenu removeAllItems];
    NSArray<Node*>* items = [self getSelectedItems];
    
    BOOL isKeePass2 = self.viewModel && !self.viewModel.locked && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    
    if ( isKeePass2 && !self.viewModel.isEffectivelyReadOnly && items.count ) {
        NSMutableSet* all = NSMutableSet.set;
        
        for ( Node* item in items ) {
            [all addObjectsFromArray:item.fields.tags.allObjects];
        }
        
        [all removeObject:kCanonicalFavouriteTag];
        
        NSArray<NSString*>* sortedTags = [all.allObjects sortedArrayUsingComparator:finderStringComparator];
        
        for (NSString* tag in sortedTags) {
            NSMenuItem* item  = [[NSMenuItem alloc] initWithTitle:tag action:@selector(onRemoveTagFromItems:) keyEquivalent:@""];
            
            item.image = [NSImage imageWithSystemSymbolName:@"tag.slash" accessibilityDescription:nil];
            
            [theMenu addItem:item];
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL theAction = menuItem.action;
    
    if ( self.viewModel && !self.viewModel.locked ) {
        BOOL isKeePass2 = self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4;
        Node* singleSelectedItem = [self getSingleSelectedItem];
        NSArray<Node*>* items = [self getSelectedItems];
        BOOL itemsContainGroup = [items anyMatch:^BOOL(Node * _Nonnull obj) {
            return obj.isGroup; 
        }];
        
        if ( !self.viewModel.isEffectivelyReadOnly ) { 
            if ( theAction == @selector(onSideBarCreateGroup:)) {
                Node* item = [self getSideBarSelectedItem];
                return  ( item != nil && item.isGroup );
            }
            else if ( theAction == @selector(onToggleFavouriteItemInSideBar:)) {
                Node* item = [self getSideBarSelectedItem];
                if ( item != nil && !item.isGroup ) {
                    BOOL favourite = [self.viewModel isFavourite:item.uuid];
                    
                    menuItem.title = favourite ? NSLocalizedString(@"browse_vc_action_unpin", @"Un-Favourite Item") : NSLocalizedString(@"browse_vc_action_pin", @"Favourite");
                    
                    if ( menuItem.image != nil ) {
                        menuItem.image = [NSImage imageWithSystemSymbolName:favourite ? @"star.slash" : @"star"  accessibilityDescription:nil];
                    }
                    
                    return YES;
                }
                else {
                    menuItem.title = NSLocalizedString(@"browse_vc_action_pin", @"Favourite");
                    return NO;
                }
            }
            else if ( theAction == @selector(onToggleFavouriteItem:)) {
                if ( singleSelectedItem != nil  && !singleSelectedItem.isGroup ) {
                    BOOL favourite = [self.viewModel isFavourite:singleSelectedItem.uuid];
                    
                    menuItem.title = favourite ? NSLocalizedString(@"browse_vc_action_unpin", @"Un-Favourite Item") : NSLocalizedString(@"browse_vc_action_pin", @"Favourite");
                    
                    if ( menuItem.image != nil ) {
                        menuItem.image = [NSImage imageWithSystemSymbolName:favourite ? @"star.slash" : @"star"  accessibilityDescription:nil];
                    }
                    
                    return YES;
                }
                else {
                    menuItem.title = NSLocalizedString(@"browse_vc_action_pin", @"Favourite");
                    return NO;
                }
            }
            else if ( theAction == @selector(onToggleExclusionFromAudit:)) {
                if ( items.count > 0 ) {
                    BOOL excluded = [self.viewModel isExcludedFromAudit:items.firstObject.uuid];
                    
                    menuItem.state = NSControlStateValueOff;
                    menuItem.title = excluded ? NSLocalizedString(@"action_include_items_in_audit_verb", @"Include in Audit") : NSLocalizedString(@"action_exclude_items_from_audit_verb", @"Exclude from Audit");
                    
                    return items.count > 0 && !itemsContainGroup;
                }
                else {
                    return NO;
                }
            }
            else if ( theAction == @selector(onToggleExclusionFromAutoFill:)) {
                if ( items.count > 0 ) {
                    BOOL excluded = [self.viewModel isExcludedFromAutoFill:items.firstObject.uuid];
                    
                    menuItem.state = NSControlStateValueOff;
                    menuItem.title = excluded ? NSLocalizedString(@"action_suggest_items_in_autofill_verb", @"Suggest in AutoFill") : NSLocalizedString(@"action_do_not_suggest_items_in_autofill_verb", @"Do not suggest in AutoFill");
                    
                    return items.count > 0 && !itemsContainGroup;
                }
                else {
                    return NO;
                }
            }
            else if ( theAction == @selector(onNewGroupWithItems:)) {
                if ( items.count && !itemsContainGroup ) {
                    return YES;
                }
                
                return NO;
            }
            else if ( theAction == @selector(onAddTagToItemsParentDummyMenuAction:) || theAction == @selector(onRemoveTagFromItemsParentDummyMenuAction:)) {
                return YES;
            }
            else if ( theAction == @selector(onAddTagToItems:) || theAction == @selector(onAddNewTagToItems:)) {
                if ( items.count && isKeePass2 && !itemsContainGroup) {
                    return YES;
                }
                
                return NO;
            }
            else if ( theAction == @selector(onRemoveTagFromItems:)) {
                if ( items.count && isKeePass2 && !itemsContainGroup ) {
                    NSMutableSet* all = NSMutableSet.set;
                    for ( singleSelectedItem in items ) {
                        [all addObjectsFromArray:singleSelectedItem.fields.tags.allObjects];
                    }
                    
                    return all.count > 0;
                }
                
                return NO;
            }
            else if (theAction == @selector(onChangeMasterPassword:)) {
                return YES;
            }
            else if (theAction == @selector( onRenameSideBarItem: )) {
                Node* item = [self getSideBarSelectedItem];
                NSString* tag = [self getSideBarSelectedTag];
                
                BOOL nodeSelected = item != nil;
                BOOL tagSelected = tag != nil;
                
                if( !nodeSelected  && !tagSelected ) {
                    return NO;
                }
                
                return YES;
            }
            else if (theAction == @selector(onSetSideBarItemIcon:)) {
                Node* item = [self getSideBarSelectedItem];
                
                if( self.viewModel.format == kPasswordSafe || item == nil ) {
                    return NO;
                }
                
                return YES;
            }
            else if (theAction == @selector(onSetItemIcon:)) {
                if(self.viewModel.format == kPasswordSafe || items.count == 0) {
                    return NO;
                }
                
                return YES;
            }
            else if (theAction == @selector(onSideBarFindFavIcons:)) {
                if ( !isKeePass2 || !StrongboxProductBundle.supportsFavIconDownloader ) {
                    return NO;
                }
                
                Node* item = [self getSideBarSelectedItem];
                if( item == nil || !item.isGroup ) {
                    return NO;
                }
                
                NSArray<Node*>* entries = [self getMinimalRecursiveEntriesOnly2:@[item] searchableOnly:YES];
                
                return entries.count != 0;
            }
            else if (theAction == @selector(onFindAllFavIcons:)) {
                if ( !isKeePass2 || !StrongboxProductBundle.supportsFavIconDownloader ) {
                    return NO;
                }
                
                return YES;
            }
            else if (theAction == @selector(onEmptyRecycleBin:)) {
                if ( !isKeePass2 ) {
                    return NO;
                }
                
                Node* item = [self getSideBarSelectedItem];
                
                if( item == nil || !item.isGroup || self.viewModel.recycleBinNode == nil || ![item.uuid isEqual:self.viewModel.recycleBinNode.uuid] ) {
                    return NO;
                }
                
                return YES;
            }
            else if (theAction == @selector(onDownloadFavIcons:)) {
                if ( !isKeePass2 || !StrongboxProductBundle.supportsFavIconDownloader) {
                    return NO;
                }
                
                NSArray<Node*>* entries = [self getMinimalSelectedEntriesOnly2:NO]; 
                
                return entries.count != 0;
            }
            else if (theAction == @selector( onDeleteSideBarItem: )) {
                Node* item = [self getSideBarSelectedItem];
                NSString* tag = [self getSideBarSelectedTag];
                
                BOOL nodeSelected = ( item != nil && item.uuid != self.viewModel.rootGroup.uuid );
                BOOL tagSelected = tag != nil;
                
                if( !nodeSelected  && !tagSelected ) {
                    return NO;
                }
                
                NSImageSymbolConfiguration* imageColour = [NSImageSymbolConfiguration configurationWithHierarchicalColor:NSColor.systemRedColor];
                
                NSImageSymbolConfiguration* imageLargeConfig = [imageColour configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge]];
                
                NSImage* image = [NSImage imageWithSystemSymbolName:@"trash.fill" accessibilityDescription:nil];
                NSImage* image2 = [image imageWithSymbolConfiguration:imageLargeConfig];
                
                menuItem.image = image2;
                
                if ( nodeSelected ) {
                    BOOL deleteWillOccur = ![self.viewModel canRecycle:item];
                    
                    NSString* loc = !deleteWillOccur ? NSLocalizedString(@"generic_recycle_item", @"Recycle Item") : NSLocalizedString(@"mac_menu_item_delete_item", @"Delete Item");
                    [menuItem setTitle:loc];
                    
                    NSImageSymbolConfiguration* imageColour = [NSImageSymbolConfiguration configurationWithHierarchicalColor:deleteWillOccur ? NSColor.systemRedColor : NSColor.systemGreenColor];
                    
                    NSImageSymbolConfiguration* imageLargeConfig = [imageColour configurationByApplyingConfiguration:[NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge]];
                    
                    NSImage* image = [NSImage imageWithSystemSymbolName:@"trash.fill" accessibilityDescription:nil];
                    NSImage* image2 = [image imageWithSymbolConfiguration:imageLargeConfig];
                    
                    menuItem.image = image2;
                    
                    return YES;
                }
                else if ( tagSelected ) {
                    NSString* loc = NSLocalizedString(@"generic_action_delete", @"Delete");
                    [menuItem setTitle:loc];
                    return YES;
                }
            }
            else if (theAction == @selector(onDuplicateItem:)) {
                return singleSelectedItem != nil;
            }
            else if (theAction == @selector(paste:)) {
                NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
                NSData* blah = [pasteboard dataForType:kDragAndDropExternalUti];
                slog(@"Validate Paste - %d", blah != nil);
                return blah != nil;
            }
        }
        
        
        
        if ( theAction == @selector(onLock:) ) {
            return YES;
        }
        else if ( theAction == @selector(onCompareAndMerge:)) { 
            return YES;
        }



        else if ( theAction == @selector(onExportDatabase:)) {
            return YES;
        }
        else if ( theAction == @selector(onSaveDatabaseAs:) ) {
            return YES;
        }
        else if(theAction == @selector(onPrintDatabase:)) {
            return YES;
        }
        else if(theAction == @selector(onPrintSelected:)) {
            return items.count > 0;
        }
        else if(theAction == @selector(onExportSelectedItems:)) {
            return items.count > 0;
        }
        else if (theAction == @selector(onViewItemHistory:)) {
            return
            singleSelectedItem != nil &&
            !singleSelectedItem.isGroup &&
            singleSelectedItem.fields.keePassHistory.count > 0 &&
            (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
        }
        else if (theAction == @selector( onSideBarItemProperties: )) {
            Node* item = [self getSideBarSelectedItem];
            
            if( item == nil || !item.isGroup) {
                return NO;
            }
            
            return isKeePass2;
        }
        else if (theAction == @selector( onSideBarDuplicateItem: )) {
            Node* item = [self getSideBarSelectedItem];
            
            if( item == nil || !item.isGroup) {
                return NO;
            }
            
            return YES;
        }
        else if ( theAction == @selector(onPrintGroupFromSideBar:)) {
            Node* item = [self getSideBarSelectedItem];
            
            if( item == nil || !item.isGroup) {
                return NO;
            }
            
            return YES;
        }
        else if ( theAction == @selector(onExportGroupFromSideBar:)) {
            Node* item = [self getSideBarSelectedItem];
            
            if( item == nil || !item.isGroup) {
                return NO;
            }
            
            return YES;
        }
        else if (theAction == @selector(onGeneralDatabaseSettings:)) {
            return YES;
        }
        else if (theAction == @selector(onConvenienceUnlockProperties:)) {
            return YES;
        }
        else if (theAction == @selector(onDatabaseEncryptionSettings:)) {
            return YES;
        }
        else if (theAction == @selector(onDatabaseAutoFillSettings:)) {
            return YES;
        }
        else if (theAction == @selector(onCopySelectedItemsToClipboard:)) {
            return items.count > 0;
        }
        else if(theAction == @selector(onLaunchUrl:) ||
                theAction == @selector(onCopyUrl:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup && singleSelectedItem.fields.url.length;
        }
        else if (theAction == @selector(onCopyTitle:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup;
        }
        else if (theAction == @selector(onCopyCustomField:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup;
        }
        else if (theAction == @selector(onCopyUsername:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup;
        }
        else if (theAction == @selector(onCopyEmail:)) {
            BOOL emailAvailable = singleSelectedItem.fields.email.length;
            return singleSelectedItem && !singleSelectedItem.isGroup && emailAvailable;
        }
        else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup && singleSelectedItem.fields.password.length;
        }
        else if (theAction == @selector(onCopyPassword:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup && singleSelectedItem.fields.password.length;
        }
        else if (theAction == @selector(onCopyTotp:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup && singleSelectedItem.fields.otpToken;
        }
        else if (theAction == @selector(onCopyNotes:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup && singleSelectedItem.fields.notes.length;
        }
        else if (theAction == @selector(onCopyUsernameAndPassword:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup;
        }
        else if (theAction == @selector(onCopyAllFields:)) {
            return singleSelectedItem && !singleSelectedItem.isGroup;
        }
        else if (theAction == @selector(copy:)) {
            return items.count > 0;
        }
        
    }
    
    
    
    
    
    
    
    
    
    if ( theAction == @selector(onVCToggleShowVerticalGridlines:)) {
        menuItem.state = self.viewModel.showVerticalGrid ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowHorizontalGridlines:)) {
        menuItem.state = self.viewModel.showHorizontalGrid ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowAlternatingGridRows:)) {
        menuItem.state = self.viewModel.showAlternatingRows ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    
    
    
    
    else if ( theAction == @selector(onVCToggleReadOnly:)) {
        menuItem.state = self.viewModel.isEffectivelyReadOnly ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleLaunchAtStartup:)) {
        menuItem.state = self.databaseMetadata.launchAtStartup ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleStartInSearchMode:)) {
        menuItem.state = self.viewModel.startWithSearch ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    else if ( theAction == @selector(onVCToggleShowEditToasts:)) {
        menuItem.state = self.viewModel.showChangeNotifications ? NSControlStateValueOn : NSControlStateValueOff;
        return YES;
    }
    
    
    
    slog(@"🔴 WindowController::validateMenuItem [%@] - NO", NSStringFromSelector(theAction));
    
    return NO;
}



- (IBAction)onSetSideBarItemIcon:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    if( item == nil ) {
        return;
    }
    
    [self onSetIconForItems:@[item]];
}

- (IBAction)onSideBarFindFavIcons:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    if( item == nil ) {
        return;
    }
    
    NSArray<Node*>* entries = [self getMinimalRecursiveEntriesOnly2:@[item] searchableOnly:YES];
    [self onDownloadFavIconsForEntries:entries];
}

- (IBAction)onFindAllFavIcons:(id)sender {
    BOOL isKeePass2 = self.viewModel && !self.viewModel.locked && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    
    if ( !isKeePass2 || !StrongboxProductBundle.supportsFavIconDownloader ) {
        return;
    }
    
    [self onDownloadFavIconsForEntries:self.viewModel.database.allSearchableEntries];
}

- (IBAction)onEmptyRecycleBin:(id)sender {
    if ( !self.viewModel || self.viewModel.locked || !self.viewModel.isKeePass2Format || self.viewModel.isEffectivelyReadOnly ) {
        return;
    }
    
    Node* item = [self getSideBarSelectedItem];
    
    if( item == nil || !item.isGroup || self.viewModel.recycleBinNode == nil || ![item.uuid isEqual:self.viewModel.recycleBinNode.uuid] ) {
        return;
    }
    
    [MacAlerts areYouSure:NSLocalizedString(@"browse_vc_action_empty_recycle_bin_are_you_sure", @"This will permanently delete all items contained within the Recycle Bin.")
                   window:self.window
               completion:^(BOOL response) {
        if ( response ) {
            [self.viewModel deleteItems:self.viewModel.recycleBinNode.children];
        }
    }];
}

- (IBAction)onDeleteSideBarItem:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    NSString* tag = [self getSideBarSelectedTag];
    
    BOOL nodeSelected = ( item != nil && item.uuid != self.viewModel.rootGroup.uuid );
    BOOL tagSelected = tag != nil;
    
    if( !nodeSelected  && !tagSelected ) {
        return;
    }
    
    if ( nodeSelected ) {
        [self onDeleteItems:@[item]];
    }
    else if ( tagSelected ) {
        [MacAlerts areYouSure:NSLocalizedString(@"are_you_sure_delete_tag_message", @"Are you sure you want to delete this tag?")
                       window:self.window
                   completion:^(BOOL response) {
            if ( response ) {
                [self.viewModel deleteTag:tag];
            }
        }];
    }
}

- (IBAction)onRenameSideBarItem:(id)sender {
    if ( !self.viewModel || self.viewModel.locked || self.viewModel.isEffectivelyReadOnly ) {
        slog(@"🔴 Cannot edit locked or read-only database");
        return;
    }
    
    Node* item = [self getSideBarSelectedItem];
    NSString* tag = [self getSideBarSelectedTag];
    
    BOOL nodeSelected = item != nil;
    BOOL tagSelected = tag != nil;
    
    if( !nodeSelected  && !tagSelected ) {
        return;
    }
    
    if ( nodeSelected ) {
        MacAlerts* ma = [[MacAlerts alloc] init];
        NSString* text = [ma input:NSLocalizedString(@"browse_vc_rename_item", @"Rename Item") defaultValue:item.title allowEmpty:NO];
        
        if ( text && [Utils trim:text].length ) {
            NSString* newTitle = [Utils trim:text];
            
            if ( ![self.viewModel setItemTitle:item title:newTitle] ) {
                slog(@"🔴 Could not rename item!");
            }
        }
    }
    else if ( tagSelected ) {
        MacAlerts* ma = [[MacAlerts alloc] init];
        NSString* text = [ma input:NSLocalizedString(@"browse_vc_rename_item", @"Rename Item") defaultValue:tag allowEmpty:NO];
        
        if ( text && [Utils trim:text].length ) {
            NSString* newTitle = [Utils trim:text];
            [self.viewModel renameTag:tag to:newTitle];
        }
    }
}

- (IBAction)onSideBarItemProperties:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    if( item == nil || !item.isGroup) {
        return;
    }
    
    GroupPropertiesViewController* vc = [GroupPropertiesViewController fromStoryboard];
    
    vc.group = item;
    vc.viewModel = self.viewModel;
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onSideBarDuplicateItem:(id)sender {
    slog(@"onSideBarDuplicateItem");
    
    Node* item = nil;
    
    if( self.viewModel && !self.viewModel.locked ) {
        item = [self getSideBarSelectedItem];
        if( item == nil || !item.isGroup) {
            return;
        }
    }
    
    if ( item ) {
        Node* destinationItem = item.parent ? item.parent : self.viewModel.rootGroup;
        
        
        
        Node* dupe = [item duplicate:[item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")] preserveTimestamps:NO];
        
        [item touch:NO touchParents:YES];
        if ( [self.viewModel addChildren:@[dupe] parent:destinationItem] ) {
            NSString* loc = NSLocalizedString(@"mac_item_duplicated", @"Item Duplicated");
            [self showPopupChangeToastNotification:loc];
        }
    }
}

- (IBAction)onSideBarCreateGroup:(id)sender {
    
    
    if ( !self.viewModel || self.viewModel.locked || self.viewModel.isEffectivelyReadOnly ) {
        slog(@"🔴 Cannot edit locked or read-only database");
        return;
    }
    
    Node* parentGroup = [self getSideBarSelectedItem];
    if ( !parentGroup || !parentGroup.isGroup ) {
        return;
    }
    
    NSString* loc = NSLocalizedString(@"browse_vc_enter_group_name_message", @"Please Enter the New Group Name:");
    NSString* name = [[MacAlerts alloc] input:loc defaultValue:NSLocalizedString(@"browse_vc_group_name", @"Group Name") allowEmpty:NO];
    
    if ( name.length ) {
        Node* newGroup;
        if ( ![self.viewModel addNewGroup:parentGroup title:name group:&newGroup] ) {
            [MacAlerts info:NSLocalizedString(@"browse_vc_cannot_create_group", @"Cannot create group")
            informativeText:NSLocalizedString(@"browse_vc_cannot_create_group_message", @"Could not create a group with this name here, possibly because one with this name already exists.")
                     window:self.window
                 completion:nil];
        }
        else if ( newGroup ) {
            [self.viewModel setNextGenNavigation:OGNavigationContextRegularHierarchy selectedGroup:newGroup.uuid];
        }
    }
}



- (IBAction)onNewGroupWithItems:(id)sender {
    slog(@"onNewGroupWithItems: [%@]", sender);
    
    NSString* loc = NSLocalizedString(@"browse_vc_enter_group_name_message", "Please Enter the New Group Name:");
    NSString* groupName = [[[MacAlerts alloc] init] input:loc defaultValue:@"" allowEmpty:NO];
    
    if ( groupName.length ) {
        NSArray<Node*>* items = [self getSelectedItems];
        
        if ( !self.viewModel.isEffectivelyReadOnly && items.count ) {
            
            NSUUID* parentGroupId = self.viewModel.nextGenNavigationContext == OGNavigationContextRegularHierarchy ? self.viewModel.nextGenNavigationContextSideBarSelectedGroup : self.viewModel.rootGroup.uuid;
            Node* parentGroup =  [self.viewModel getItemById:parentGroupId];
            
            if ( parentGroup == nil ) {
                slog(@"🔴 Could not find Parent Group!");
                return;
            }
            
            Node* newGroup = nil;
            if ( ![self.viewModel moveItemsIntoNewGroup:items parentGroup:parentGroup title:groupName group:&newGroup] ) {
                slog(@"🔴 Could not move items into new group!");
                
                [MacAlerts info:NSLocalizedString(@"browse_vc_cannot_create_group", @"Cannot create group")
                informativeText:NSLocalizedString(@"browse_vc_cannot_create_group_message", @"Could not create a group with this name here, possibly because one with this name already exists.")
                         window:self.window
                     completion:nil];
            }
            else {
                [self.viewModel setNextGenNavigation:OGNavigationContextRegularHierarchy selectedGroup:newGroup.uuid];
            }
        }
    }
}



- (IBAction)onToggleExclusionFromAudit:(id)sender {
    slog(@"onToggleExclusionFromAudit: [%@]", sender);
    
    NSArray<Node*>* items = [self getSelectedItems];
    
    if ( items && items.count ) {
        BOOL exclude = ![self.viewModel isExcludedFromAudit:items.firstObject.uuid]; 
        
        [self.viewModel batchExcludeItemsFromAudit:items exclude:exclude];
    }
}

- (IBAction)onToggleExclusionFromAutoFill:(id)sender {
    slog(@"onToggleExclusionFromAutoFill: [%@]", sender);
    
    NSArray<Node*>* items = [self getSelectedItems];
    
    if ( items && items.count ) {
        BOOL exclude = ![self.viewModel isExcludedFromAutoFill:items.firstObject.uuid]; 
        
        [self.viewModel batchExcludeItemsFromAutoFill:items exclude:exclude];
    }
}

- (IBAction)onPrintGroupFromSideBar:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    
    if ( item && item.isGroup ) {
        NSArray<Node*>* items = item.allChildRecords;
        
        NSString* htmlString = [self.viewModel getHtmlPrintStringForItems:self.databaseMetadata.nickName items:items];
        
        [self printHtmlString:htmlString];
    }
}



- (IBAction)onToggleFavouriteItemInSideBar:(id)sender {
    
    
    Node* item = [self getSideBarSelectedItem];
    
    if ( item && !item.isGroup ) {
        [self.viewModel toggleFavourite:item.uuid];
    }
}

- (IBAction)onToggleFavouriteItem:(id)sender {
    
    
    Node* item = [self getSingleSelectedItem];
    
    if ( item ) {
        [self.viewModel toggleFavourite:item.uuid];
    }
}



- (IBAction)onAddTagToItemsParentDummyMenuAction:(id)sender {
    
}
- (IBAction)onRemoveTagFromItemsParentDummyMenuAction:(id)sender {
    
}

- (IBAction)onAddTagToItems:(id)sender {
    
    
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    NSString* tag = menuItem.title;
    [self addTagToItems:tag];
}

- (void)addTagToItems:(NSString*)tag {
    NSArray<Node*>* items = [self getSelectedItems];
    
    BOOL isKeePass2 = self.viewModel && !self.viewModel.locked && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    
    if ( isKeePass2 && !self.viewModel.isEffectivelyReadOnly && tag.length && items.count ) {
        [self.viewModel addTagToItems:items tag:tag];
    }
}

- (IBAction)onAddNewTagToItems:(id)sender {
    
    
    NSString* loc = NSLocalizedString(@"mac_vc_please_enter_a_tag", "Enter a new tag to add to this item");
    NSString* tag = [[[MacAlerts alloc] init] input:loc defaultValue:@"" allowEmpty:NO];
    
    if ( tag.length ) {
        [self addTagToItems:tag];
    }
}

- (IBAction)onRemoveTagFromItems:(id)sender {
    
    
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    
    BOOL isKeePass2 = self.viewModel && !self.viewModel.locked && (self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4);
    
    NSString* tag = menuItem.title;
    NSArray<Node*>* items = [self getSelectedItems];
    
    if ( isKeePass2 && !self.viewModel.isEffectivelyReadOnly && tag.length && items.count ) {
        [self.viewModel removeTagFromItems:items tag:tag];
    }
}



- (void)unsubscribeFromNotifications {

    
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
}

- (void)listenToEventsOfInterest {

    
    [self unsubscribeFromNotifications]; 
    
    if ( !self.databaseIsLocked ) { 
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSettingsChanged:) name:kSettingsChangedNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onDatabaseModelPreferencesChanged:) name:kModelUpdateNotificationDatabasePreferenceChanged object:nil];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDatabasePreferencesChanged:) name:kUpdateNotificationDatabasePreferenceChanged object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDatabasePreferencesChanged:) name:kDatabasesCollectionLockStateChangedNotification object:nil];
}

- (void)onSettingsChanged:(NSNotification*)notification {
    slog(@"WindowController::onSettingsChanged");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindFloatWindowOnTop];
        [self bindScreenCaptureAllowed];
    });
}

- (void)bindFloatWindowOnTop {
    [self.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (void)onDatabasePreferencesChanged:(NSNotification*)notification {
    if ( ![notification.object isEqualToString:self.viewModel.databaseUuid] ) {
        return;
    }
    
    [self onGenericDatabasePreferencesChanged];
}

- (void)onDatabaseModelPreferencesChanged:(NSNotification*)notification {
    if ( notification.object != self.viewModel ) {
        return;
    }
    
    [self onGenericDatabasePreferencesChanged];
}

- (void)onGenericDatabasePreferencesChanged {

    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self synchronizeWindowTitleWithDocumentName]; 
    });
}

- (void)onLock:(id)sender {
    [self.viewModel.document initiateLockSequence];
}



- (IBAction)onSetItemIcon:(id)sender {
    NSArray<Node*>* items = [self getSelectedItems];
    
    [self onSetIconForItems:items];
}

- (void)onSetIconForItems:(NSArray<Node*>*)items {
    if(self.viewModel.format == kPasswordSafe || items.count == 0) {
        return;
    }
    
    __weak WindowController* weakSelf = self;
    self.selectPredefinedIconController = [[SelectPredefinedIconController alloc] initWithWindowNibName:@"SelectPredefinedIconController"];
    self.selectPredefinedIconController.iconPool = self.viewModel.customIcons.allObjects;
    self.selectPredefinedIconController.hideSelectFile = !self.viewModel.formatSupportsCustomIcons;
    self.selectPredefinedIconController.hideFavIconButton = !self.viewModel.formatSupportsCustomIcons || !StrongboxProductBundle.supportsFavIconDownloader;
    
    self.selectPredefinedIconController.iconSet = self.viewModel.keePassIconSet;
    
    self.selectPredefinedIconController.onSelectedItem = ^(NodeIcon * _Nullable icon, BOOL showFindFavIcons) {
        if(showFindFavIcons) {
            [weakSelf onDownloadFavIcons:nil];
        }
        else {
            [weakSelf.viewModel batchSetIcons:items icon:icon];
        }
    };
    
    [self.window beginSheet:self.selectPredefinedIconController.window  completionHandler:nil];
}

- (IBAction)onDownloadFavIcons:(id)sender {
    NSArray<Node*>* entries = [self getMinimalSelectedEntriesOnly2:NO];
    
    [self onDownloadFavIconsForEntries:entries];
}

- (void)onDownloadFavIconsForEntries:(NSArray<Node*>*)entries { 
#ifndef NO_FAVICON_LIBRARY
    if(self.viewModel.format == kPasswordSafe || entries.count == 0) {
        return;
    }
    
    FavIconDownloader *vc = [FavIconDownloader newVC];
    
    vc.nodes = entries;
    vc.viewModel = self.viewModel;
    
    __weak WindowController* weakSelf = self;
    vc.onDone = ^(BOOL go, NSDictionary<NSUUID *,NodeIcon *> * _Nullable selectedFavIcons) {
        if(go) {
            [weakSelf.viewModel batchSetIcons:selectedFavIcons];
        }
    };
    
    [self.contentViewController presentViewControllerAsSheet:vc];
#endif
}

- (IBAction)onPrintDatabase:(id)sender {
    [self printDatabase];
}

- (IBAction)onPrintSelected:(id)sender {
    NSArray<Node*>* items = [self getSelectedItems];
    
    if ( items.count > 0 ) {
        [self printItems];
    }
}

- (void)printItems {
    NSArray<Node*>* items = [self getSelectedItems];
    
    NSString* htmlString = [self.viewModel getHtmlPrintStringForItems:self.databaseMetadata.nickName items:items];
    
    [self printHtmlString:htmlString];
}

- (void)printDatabase {
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    NSString* htmlString = [self.viewModel getHtmlPrintString:self.databaseMetadata.nickName];
    [self printHtmlString:htmlString];
}

- (void)printHtmlString:(NSString*)htmlString {
    [self requestVerifyMasterCredentials:NSLocalizedString(@"verify_creds_before_print_bio_message_suffix", @"verify existing credentials before you can print.")
                       manualCkfHeadline:NSLocalizedString(@"verify_creds_headline", @"Verify Master Credentials")
                    manualCkfSubheadline:NSLocalizedString(@"verify_creds_before_print_subhead", @"For security reasons your current master credentials must be verified before you can print.")
                              completion:^(BOOL userCancelled, BOOL verified, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [MacAlerts error:error window:self.window];
            }
            else if ( userCancelled ) {
                
            }
            else if ( verified ) {
                [self printHtmlStringAfterVerify:htmlString];
            }
            else {
                [self onLock:nil];
                
                [MacAlerts info:NSLocalizedString(@"credentials_incorrect_database_locked", @"Those credentials are incorrect and your database has now been locked for security reasons.")
                         window:self.window];
            }
        });
    }];
}

- (void)printHtmlStringAfterVerify:(NSString*)htmlString {
    WebView *webView = [[WebView alloc] init];
    [webView.mainFrame loadHTMLString:htmlString baseURL:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:webView.mainFrame.frameView.documentView
                                                                   printInfo:NSPrintInfo.sharedPrintInfo];
        
        [printOp runOperation];
    });
}



- (IBAction)onChangeMasterPassword:(id)sender {
    slog(@"onChangeMasterPassword: %hhd, %hhd", self.viewModel.document.isDocumentEdited, self.viewModel.document.hasUnautosavedChanges);
    
    if ( self.viewModel.document.isDocumentEdited ) {
        [MacAlerts yesNo:NSLocalizedString(@"generic_unsaved_changes", @"Unsaved Changes")
         informativeText:NSLocalizedString(@"unsaved_changes_question_save_now", @"You have pending unsaved changes which should be saved before continuing.\n\nWould you like to save now?")
                  window:self.window completion:^(BOOL yesNo) {
            if ( yesNo ) {
                [self.viewModel.document saveDocumentWithDelegate:self
                                                  didSaveSelector:@selector(onChangeMasterPassword:) 
                                                      contextInfo:nil];
            }
        }];
    }
    else {
        [self requestVerifyMasterCredentials:NSLocalizedString(@"verify_creds_before_changing_bio_message_suffix", @"verify existing credentials before you can change them")
                           manualCkfHeadline:NSLocalizedString(@"verify_creds_headline", @"Verify Master Credentials")
                        manualCkfSubheadline:NSLocalizedString(@"verify_creds_subhead", @"For security reasons your current master credentials must be verified before you can change them.")
                                  completion:^(BOOL userCancelled, BOOL verified, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( error ) {
                    [MacAlerts error:error window:self.window];
                }
                else if ( userCancelled ) {
                    
                }
                else if ( verified ) {
                    [self promptToChangeMasterCredentials:^(BOOL okCancel) {
                        if(okCancel) {
                            [self.viewModel.document saveDocumentWithDelegate:self
                                                              didSaveSelector:@selector(onMasterCredentialsChangedAndSaved:)
                                                                  contextInfo:nil];
                        }
                    }];
                }
                else if ( !verified ) {
                    [self onLock:nil];
                    
                    [MacAlerts info:NSLocalizedString(@"credentials_incorrect_database_locked", @"Those credentials are incorrect and your database has now been locked for security reasons.")
                             window:self.window];
                }
            });
        }];
    }
}

- (void)requestVerifyMasterCredentials:(NSString*)biometricMessage
                     manualCkfHeadline:(NSString*)manualCkfHeadline
                  manualCkfSubheadline:(NSString*)manualCkfSubheadline
                            completion:(void (^)(BOOL userCancelled, BOOL verified, NSError* _Nullable error))completion {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.viewModel.databaseUuid];
    if ( url == nil ) {
        completion(NO, NO, [Utils createNSError:@"Could not get working cache to verify credentials. Cannot continue." errorCode:-12345]);
        return;
    }
    
    MacCompositeKeyDeterminer* ckd =
    [MacCompositeKeyDeterminer determinerWithViewController:self.contentViewController
                                                   database:self.viewModel.databaseMetadata
                           isNativeAutoFillAppExtensionOpen:NO];
    
    ckd.verifyCkfsMode = YES; 
    
    [ckd getCkfs:biometricMessage
  manualHeadline:manualCkfHeadline
   manualSubhead:manualCkfSubheadline
      completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if ( result == kGetCompositeKeyResultError ) {
            completion(NO, NO, error);
        }
        else if ( result == kGetCompositeKeyResultSuccess ) {
            [self verifyCkfsAreCorrect:factors url:url completion:completion];
        }
        else {
            completion(YES, NO, nil);
        }
    }];
}

- (void)verifyCkfsAreCorrect:(CompositeKeyFactors*)factors
                         url:(NSURL*)url
                  completion:(void (^)(BOOL userCancelled, BOOL correct, NSError* _Nullable error))completion {
    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.viewModel.databaseMetadata
                                                        viewController:self.contentViewController
                                                         forceReadOnly:NO
                                      isNativeAutoFillAppExtensionOpen:NO
                                                           offlineMode:NO];
    

    
    [unlocker unlockLocalWithKey:factors
              keyFromConvenience:NO
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        
        
        if ( result == kUnlockDatabaseResultSuccess ) {
            completion(NO, YES, nil);
        }
        else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
            completion(NO, NO, nil);
        }
        else if ( result == kUnlockDatabaseResultError ) {
            completion(NO, NO, error);
        }
        else {
            completion(NO, NO, nil);
        }
    }];
    




























}

- (void)promptToChangeMasterCredentials:(void (^)(BOOL okCancel))completion {
    self.changeMasterPassword = [CreateDatabaseOrSetCredentialsWizard newSetCredentialsWizard:self.viewModel.format 
                                                                              keyFileBookmark:self.databaseMetadata.keyFileBookmark
                                                                                yubiKeyConfig:self.databaseMetadata.yubiKeyConfiguration];
    
    [self.window beginSheet:self.changeMasterPassword.window
          completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSModalResponseOK) {
            NSError* error;
            CompositeKeyFactors* ckf = [self.changeMasterPassword generateCkfFromSelectedFactors:self.contentViewController error:&error];
            
            if ( ckf ) {
                [self changeMasterCredentials:ckf];
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_error_could_not_generate_composite_key", @"Could not generate Composite Key");
                [MacAlerts error:loc error:error window:self.window];
            }
        }
        
        if(completion) {
            completion(returnCode == NSModalResponseOK);
        }
    }];
}

- (void)changeMasterCredentials:(CompositeKeyFactors*)ckf {
    [self.viewModel setCompositeKeyFactors:ckf];
    
    MacDatabasePreferences* md = self.databaseMetadata;
    
    if ( md.isConvenienceUnlockEnabled ) {
        md.conveniencePassword = ckf.password;
        md.conveniencePasswordHasBeenStored = YES;
    }
    
    if ( self.changeMasterPassword.selectedKeyFileBookmark && !Settings.sharedInstance.doNotRememberKeyFile ) {
        md.keyFileBookmark = self.changeMasterPassword.selectedKeyFileBookmark;
    }
    else {
        md.keyFileBookmark = nil;
    }
    
    md.yubiKeyConfiguration = self.changeMasterPassword.selectedYubiKeyConfiguration;
}

- (void)onMasterCredentialsChangedAndSaved:(id)param {
    
    
}



- (IBAction)onVCToggleShowVerticalGridlines:(id)sender {
    self.viewModel.showVerticalGrid = !self.viewModel.showVerticalGrid;
}

- (IBAction)onVCToggleShowHorizontalGridlines:(id)sender {
    self.viewModel.showHorizontalGrid = !self.viewModel.showHorizontalGrid;
}

- (IBAction)onVCToggleShowAlternatingGridRows:(id)sender {
    self.viewModel.showAlternatingRows = !self.viewModel.showAlternatingRows;
}





- (IBAction)onVCToggleReadOnly:(id)sender {
    if ( !self.viewModel.readOnly ) {
        if ( [DatabasesCollection.shared databaseHasEditsOrIsBeingEditedWithUuid:self.viewModel.databaseUuid] ) {
            [MacAlerts info:NSLocalizedString(@"read_only_unavailable_title", @"Read Only Unavailable")
            informativeText:NSLocalizedString(@"read_only_unavailable_pending_changes_message", @"You currently have changes pending and so you cannot switch to Read Only mode. You must save or discard your current changes first.")
                     window:self.window
                 completion:nil];
            return;
        }
    }
    
    self.viewModel.readOnly = !self.viewModel.readOnly;
}

- (IBAction)onVCToggleLaunchAtStartup:(id)sender {
    self.viewModel.launchAtStartup = !self.viewModel.launchAtStartup;
}

- (IBAction)onVCToggleStartInSearchMode:(id)sender {
    self.viewModel.startWithSearch = !self.viewModel.startWithSearch;
}

- (IBAction)onVCToggleShowEditToasts:(id)sender {
    self.viewModel.showChangeNotifications = !self.viewModel.showChangeNotifications;
}

- (IBAction)onGeneralDatabaseSettings:(id)sender {
    DatabaseSettingsTabViewController* vc = [DatabaseSettingsTabViewController fromStoryboard];
    [vc setModel:self.viewModel initialTab:kDatabaseSettingsInitialTabGeneral];
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onConvenienceUnlockProperties:(id)sender {
    DatabaseSettingsTabViewController* vc = [DatabaseSettingsTabViewController fromStoryboard];
    [vc setModel:self.viewModel initialTab:kDatabaseSettingsInitialTabTouchId];
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onDatabaseAutoFillSettings:(id)sender {
    DatabaseSettingsTabViewController* vc = [DatabaseSettingsTabViewController fromStoryboard];
    [vc setModel:self.viewModel initialTab:kDatabaseSettingsInitialTabAutoFill];
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onDatabaseEncryptionSettings:(id)sender {
    DatabaseSettingsTabViewController* vc = [DatabaseSettingsTabViewController fromStoryboard];
    [vc setModel:self.viewModel initialTab:kDatabaseSettingsInitialTabEncryption];
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onViewItemHistory:(id)sender {
    Node *item = [self getSingleSelectedItem];
    
    if(item == nil ||
       item.isGroup || item.fields.keePassHistory.count == 0 ||
       (!(self.viewModel.format == kKeePass || self.viewModel.format == kKeePass4))) {
        return;
    }
    
    MacKeePassHistoryViewController* vc = [MacKeePassHistoryViewController instantiateFromStoryboard];
    
    __weak WindowController* weakSelf = self;
    vc.onDeleteHistoryItem = ^(Node * _Nonnull node) {
        [weakSelf.viewModel deleteHistoryItem:item historicalItem:node];
    };
    vc.onRestoreHistoryItem = ^(Node * _Nonnull node) {
        [weakSelf.viewModel restoreHistoryItem:item historicalItem:node];
    };
    
    vc.model = self.viewModel;
    vc.history = item.fields.keePassHistory;
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (IBAction)onDuplicateItem:(id)sender {
    Node* item = nil;
    if( self.viewModel && !self.viewModel.locked ) {
        item = [self getSingleSelectedItem];
    }
    if ( !item ) {
        return;
    }
    
    NSString* newTitle = [item.title stringByAppendingString:NSLocalizedString(@"browse_vc_duplicate_title_suffix", @" Copy")];
    
    BOOL showReferencingOptions = self.viewModel.database.originalFormat != kPasswordSafe;

    Settings* settings = Settings.sharedInstance;
    __weak WindowController* weakSelf = self;
    NSViewController* vc = [SwiftUIViewFactory getDuplicateItemOptionsViewWithShowReferencingOptions:showReferencingOptions
                                                                                               title:newTitle
                                                                                   referencePassword:settings.duplicateItemReferencePassword
                                                                                   referenceUsername:settings.duplicateItemReferenceUsername
                                                                                  preserveTimestamps:settings.duplicateItemPreserveTimestamp
                                                                                      editAfterwards:settings.duplicateItemEditAfterwards
                                                                                          completion:^(BOOL cancelled, NSString * _Nonnull title, BOOL referencePassword, BOOL referenceUsername, BOOL preserveTimestamp, BOOL editAfterwards) {
        [Utils dismissViewControllerCorrectly:weakSelf.contentViewController.presentedViewControllers.lastObject];
        
        settings.duplicateItemReferencePassword = referencePassword;
        settings.duplicateItemReferenceUsername = referenceUsername;
        settings.duplicateItemPreserveTimestamp = preserveTimestamp;
        settings.duplicateItemEditAfterwards = editAfterwards;
        
        if ( cancelled ) {
            return;
        }
        
        [weakSelf duplicateItemWithOptions:item.uuid
                                     title:title
                         referencePassword:referencePassword
                         referenceUsername:referenceUsername
                         preserveTimestamp:preserveTimestamp
                            editAfterwards:editAfterwards];
    }];
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (void)duplicateItemWithOptions:(NSUUID*)itemId
                           title:(NSString * _Nonnull)title
               referencePassword:(BOOL)referencePassword
               referenceUsername:(BOOL)referenceUsername
               preserveTimestamp:(BOOL)preserveTimestamp
                  editAfterwards:(BOOL)editAfterwards {
    Node* dupe = [self.viewModel duplicateWithOptions:itemId
                                                title:title
                                    preserveTimestamp:preserveTimestamp
                                    referencePassword:referencePassword
                                    referenceUsername:referenceUsername];
    
    if ( dupe ) {
        NSString* loc = NSLocalizedString(@"mac_item_duplicated", @"Item Duplicated");
        [self showPopupChangeToastNotification:loc];
        
        if ( editAfterwards ) {
            NextGenSplitViewController* vc = (NextGenSplitViewController*)self.contentViewController;
            [vc editEntryWithUuid:dupe.uuid];
        }
    }
    else {
        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error") window:self.window];
    }
}

- (void)onDeleteItems:(NSArray<Node*>*)items {
    [self onDeleteItems:items completion:nil];
}

- (void)onDeleteItems:(NSArray<Node*>*)items
           completion:( void (^ _Nullable)(BOOL success) )completion {
    NSDictionary* grouped = [items groupBy:^id _Nonnull(Node * _Nonnull obj) {
        BOOL delete = [self.viewModel canRecycle:obj];
        return @(delete);
    }];
    
    Node* selectAfterDelete = nil;
    if ( items.count == 1 && items.firstObject.isGroup ) {
        Node* node = items.firstObject;
        selectAfterDelete = node.parent;
    }
    
    const NSArray<Node*> *toBeDeleted = grouped[@(NO)];
    const NSArray<Node*> *toBeRecycled = grouped[@(YES)];
    
    if ( toBeDeleted == nil ) {
        [self postValidationRecycleAllItemsWithConfirmPrompt:toBeRecycled completion:completion];
    }
    else {
        if ( toBeRecycled == nil ) {
            [self postValidationDeleteAllItemsWithConfirmPrompt:toBeDeleted completion:completion];
        }
        else { 
            [self postValidationPartialDeleteRecycleWithConfirm:toBeDeleted toBeRecycled:toBeRecycled completion:completion];
        }
    }
}

- (void)postValidationPartialDeleteRecycleWithConfirm:(const NSArray<Node*>*)toBeDeleted
                                         toBeRecycled:(const NSArray<Node*>*)toBeRecycled 
                                           completion:( void (^ _Nullable)(BOOL success) )completion {
    [MacAlerts yesNo:NSLocalizedString(@"browse_vc_partial_recycle_alert_title", @"Partial Recycle")
     informativeText:NSLocalizedString(@"browse_vc_partial_recycle_alert_message", @"Some of the items you have selected cannot be recycled and will be permanently deleted. Is that ok?")
              window:self.window
          completion:^(BOOL yesNo) {
        if (yesNo) {
            
            
            
            [self.viewModel deleteItems:toBeDeleted];
            
            BOOL fail = ![self.viewModel recycleItems:toBeRecycled];
            
            if(fail) {
                [MacAlerts info:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                informativeText:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")
                         window:self.window
                     completion:^{
                    if ( completion ) {
                        completion(NO);
                    }
                }];
            }
            else {
                if ( completion ) {
                    completion(YES);
                }
            }
        }
        else {
            if ( completion ) {
                completion(NO);
            }
        }
    }];
}

- (void)postValidationDeleteAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items
                                           completion:( void (^ _Nullable)(BOOL success) )completion {
    NSString* title = NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?");
    
    NSString* message;
    
    if (items.count > 1) {
        message = NSLocalizedString(@"browse_vc_are_you_sure_delete", @"Are you sure you want to permanently delete these item(s)?");
    }
    else {
        Node* item = items.firstObject;
        message = [NSString stringWithFormat:NSLocalizedString(@"browse_vc_are_you_sure_delete_fmt", @"Are you sure you want to permanently delete '%@'?"),
                   [self.viewModel dereference:item.title node:item]];
    }
    
    [MacAlerts yesNo:title
     informativeText:message
              window:self.window completion:^(BOOL yesNo) {
        if (yesNo) {
            [self.viewModel deleteItems:items];
            if ( completion ) {
                completion(YES);
            }
        }
        else {
            if ( completion ) {
                completion(NO);
            }
        }
    }];
}

- (void)postValidationRecycleAllItemsWithConfirmPrompt:(const NSArray<Node*>*)items
                                            completion:( void (^ _Nullable)(BOOL success) )completion {
    NSString* title = NSLocalizedString(@"browse_vc_are_you_sure", @"Are you sure?");
    NSString* message;
    if (items.count > 1) {
        message = NSLocalizedString(@"browse_vc_are_you_sure_recycle", @"Are you sure you want to send these item(s) to the Recycle Bin?");
    }
    else {
        Node* item = items.firstObject;
        message = [NSString stringWithFormat:NSLocalizedString(@"mac_are_you_sure_recycle_bin_yes_no_fmt", @"Are you sure you want to send '%@' to the Recycle Bin?"),
                   [self.viewModel dereference:item.title node:item]];
    }
    
    [MacAlerts yesNo:title
     informativeText:message
              window:self.window
          completion:^(BOOL yesNo) {
        if (yesNo) {
            BOOL fail = ![self.viewModel recycleItems:items];
            
            if(fail) {
                [MacAlerts info:NSLocalizedString(@"browse_vc_error_deleting", @"Error Deleting")
                informativeText:NSLocalizedString(@"browse_vc_error_deleting_message", @"There was a problem deleting a least one of these items.")
                         window:self.window
                     completion:^{
                    if ( completion ) {
                        completion(NO);
                    }
                }];
            }
            else {
                if ( completion ) {
                    completion(YES);
                }
            }
        }
    }];
}



-(void)dereferenceAndCopyToPasteboard:(NSString*)text item:(Node*)item {
    if(!item || !text.length) {
        [[NSPasteboard generalPasteboard] clearContents];
        return;
    }
    
    NSString* deref = [self.viewModel dereference:text node:item];
    
    [self copyConcealedAndMaybeMinimize:deref];
}

- (void)copyConcealedAndMaybeMinimize:(NSString*)string {
    [ClipboardManager.sharedInstance copyConcealedString:string];
    
    if ( Settings.sharedInstance.miniaturizeOnCopy ) {
        [self.window miniaturize:nil];
    }
    
    if ( Settings.sharedInstance.hideOnCopy ) {
        [NSApp hide:nil];
    }
}



- (id)copy:(id)sender {
    slog(@"WindowController::copy - [%@]", self.window.firstResponder );
    
    NextGenSplitViewController* vc = (NextGenSplitViewController*)self.contentViewController;
    DetailViewController* detail = vc.childViewControllers[2];
    
    if ( [detail handleCopy] ) { 
        return nil;
    }
    
    NSArray<Node*>* selected = [self getSelectedItems];
    
    if ( selected.count == 0) {
        slog(@"Nothing selected!");
        return nil;
    }
    
    if (selected.count == 1 && !selected.firstObject.isGroup ) {
        slog(@"Only one selected item and non group... copying password");
        [self onCopyPassword:nil];
    }
    else {
        slog(@"Multiple selected or group... copying items to clipboard");
        [self onCopySelectedItemsToClipboard:nil];
    }
    
    return nil;
}

- (id)paste:(id)sender { 
    NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
    NSData* blah = [pasteboard dataForType:kDragAndDropExternalUti];
    if ( blah == nil ) {
        return nil;
    }
    
    Node* selected = [self getSingleSelectedItem];
    Node* destinationItem = self.viewModel.rootGroup;
    if(selected) {
        destinationItem = selected.isGroup ? selected : selected.parent;
    }
    
    NSUInteger itemCount = [self pasteItemsFromPasteboard:pasteboard destinationItem:destinationItem internal:NO clear:NO];
    if ( itemCount == 0 ) {
        [MacAlerts info:@"Could not paste! Unknown Error." window:self.window];
    }
    else {
        NSString* loc = itemCount == 1 ? NSLocalizedString(@"mac_item_pasted_from_clipboard", @"Item Pasted from Clipboard") :
        NSLocalizedString(@"mac_items_pasted_from_clipboard", @"Items Pasted from Clipboard");
        
        [self showPopupChangeToastNotification:loc];
    }
    
    return nil;
}

- (NSUInteger)pasteItemsFromPasteboard:(NSPasteboard*)pasteboard
                       destinationItem:(Node*)destinationItem
                              internal:(BOOL)internal
                                 clear:(BOOL)clear {
    if(![pasteboard propertyListForType:kDragAndDropExternalUti] &&
       ![pasteboard dataForType:kDragAndDropInternalUti]) {
        return NO;
    }
    
    if ( internal ) {
        NSArray<NSString*>* serializationIds = [pasteboard propertyListForType:kDragAndDropInternalUti];
        NSArray<Node*>* sourceItems = [serializationIds map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
            return [self.viewModel getItemFromSerializationId:obj];
        }];
        
        BOOL result = [self.viewModel move:sourceItems destination:destinationItem];
        
        if(clear) {
            [pasteboard clearContents];
        }
        
        return result ? sourceItems.count : 0;
    }
    else if(destinationItem.isGroup) { 
        NSData* json = [pasteboard dataForType:kDragAndDropExternalUti];
        if(json && destinationItem.isGroup) {
            NSUInteger ret = [self pasteFromExternal:json destinationItem:destinationItem];
            if(clear) {
                [pasteboard clearContents];
            }
            return ret;
        }
    }
    
    if(clear) {
        [pasteboard clearContents];
    }
    
    return 0;
}

- (NSUInteger)pasteFromExternal:(NSData*)json destinationItem:(Node*)destinationItem {
    NSError* error;
    NSDictionary* serialized = [NSJSONSerialization JSONObjectWithData:json options:kNilOptions error:&error];
    
    if(!serialized) {
        [MacAlerts error:@"Could not deserialize!" error:error window:self.window];
        return NO;
    }
    
    NSNumber* sourceFormatNum = serialized[@"sourceFormat"];
    DatabaseFormat sourceFormat = sourceFormatNum.integerValue;
    NSArray<NSDictionary*>* serializedNodes = serialized[@"nodes"];
    
    BOOL keePassGroupTitleRules = self.viewModel.format != kPasswordSafe;
    
    
    
    NSMutableArray<Node*>* nodes = @[].mutableCopy;
    NSError* err;
    for (NSDictionary* obj in serializedNodes) {
        Node* n = [Node deserialize:obj parent:destinationItem keePassGroupTitleRules:keePassGroupTitleRules error:&err];
        
        if(!n) {
            [MacAlerts error:err window:self.window];
            return 0;
        }
        
        [nodes addObject:n];
    }
    
    BOOL destinationIsRootGroup = (destinationItem == nil || destinationItem == self.viewModel.rootGroup);
    
    [DatabaseFormatIncompatibilityHelper processFormatIncompatibilities:nodes
                                                 destinationIsRootGroup:destinationIsRootGroup
                                                           sourceFormat:sourceFormat
                                                      destinationFormat:self.viewModel.format
                                                    confirmChangesBlock:^(NSString * _Nullable confirmMessage, IncompatibilityConfirmChangesResultBlock  _Nonnull resultBlock) {
        [MacAlerts yesNo:confirmMessage window:self.window completion:^(BOOL yesNo) {
            resultBlock(yesNo);
        }];
    } completion:^(BOOL go, NSArray<Node *> * _Nullable compatibleFilteredNodes) {
        if ( go ) {
            [self continuePaste:compatibleFilteredNodes destinationItem:destinationItem];
        }
    }];
    
    return nodes.count;
}

- (void)continuePaste:(NSArray<Node*>*)nodes
      destinationItem:(Node*)destinationItem {
    BOOL success = [self.viewModel addChildren:nodes parent:destinationItem];
    
    if(!success) {
        [MacAlerts info:@"Could Not Paste"
        informativeText:@"Could not place these items here. Unknown error."
                 window:self.window
             completion:nil];
    }
}

- (IBAction)onCopySelectedItemsToClipboard:(id)sender {
    NSArray* selected = [self getSelectedItems];
    
    if (selected.count) {
        NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName:kStrongboxPasteboardName];
        [self placeItemsOnPasteboard:pasteboard items:selected];
        
        NSString* loc = selected.count == 1 ? NSLocalizedString(@"mac_copied_item_to_clipboard", @"Item Copied to Clipboard") :
        NSLocalizedString(@"mac_copied_items_to_clipboard", @"Items Copied to Clipboard");
        
        [self showPopupChangeToastNotification:loc];
    }
}

- (BOOL)placeItemsOnPasteboard:(NSPasteboard*)pasteboard items:(NSArray<Node*>*)items {
    [pasteboard declareTypes:@[kDragAndDropInternalUti,
                               kDragAndDropExternalUti]
                       owner:self];
    
    NSArray<Node*>* minimalNodeSet = [self.viewModel getMinimalNodeSet:items].allObjects;
    
    
    
    NSArray<NSString*>* internalSerializationIds = [self getInternalSerializationIds:minimalNodeSet];
    [pasteboard setPropertyList:internalSerializationIds forType:kDragAndDropInternalUti];
    
    
    
    NSData* json = [self getJsonForNodes:minimalNodeSet];
    [pasteboard setData:json forType:kDragAndDropExternalUti];
    
    return YES;
}

- (NSArray<NSString*>*)getInternalSerializationIds:(NSArray<Node*>*)nodes {
    return [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [self.viewModel.database getCrossSerializationFriendlyIdId:obj.uuid];
    }];
}

- (NSData*)getJsonForNodes:(NSArray<Node*>*)nodes {
    SerializationPackage *serializationPackage = [[SerializationPackage alloc] init];
    
    
    
    NSArray<NSDictionary*>* nodeDictionaries = [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj serialize:serializationPackage];
    }];
    
    
    
    NSDictionary *serialized = @{ @"sourceFormat" : @(self.viewModel.format),
                                  @"nodes" : nodeDictionaries };
    
    
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:serialized options:kNilOptions error:&error];
    
    if(!data) {
        [MacAlerts error:@"Could not serialize these items!" error:error window:self.window];
    }
    
    return data;
}





- (IBAction)onCopyTitle:(id)sender {
    [self copyTitle:[self getSingleSelectedItem]];
}

- (IBAction)onCopyUsername:(id)sender {
    [self copyUsername:[self getSingleSelectedItem]];
}

- (IBAction)onCopyEmail:(id)sender {
    [self copyEmail:[self getSingleSelectedItem]];
}

- (IBAction)onCopyUrl:(id)sender {
    [self copyUrl:[self getSingleSelectedItem]];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    Node* item = [self getSingleSelectedItem];
    [self copyPassword:item];
    [self onLaunchUrl:sender];
}

- (IBAction)onCopyNotes:(id)sender {
    [self copyNotes:[self getSingleSelectedItem]];
}

- (IBAction)onCopyUsernameAndPassword:(id)sender {
    [self copyUsernameAndPassword:[self getSingleSelectedItem]];
}

- (IBAction)onCopyAllFields:(id)sender {
    [self copyAllFields:[self getSingleSelectedItem]];
}

- (IBAction)onCopyPassword:(id)sender {
    [self copyPassword:[self getSingleSelectedItem]];
}

- (IBAction)onCopyTotp:(id)sender {
    [self copyTotp:[self getSingleSelectedItem]];
}

- (IBAction)onCopyCustomField:(id)sender {
    slog(@"onCopyCustomField: [%@]", sender);
    
    Node* item = [self getSingleSelectedItem];
    
    if ( !item ) {
        return;
    }
    
    NSMenuItem* menuItem = (NSMenuItem*)sender;
    NSString* key = menuItem.title;
    
    StringValue* field = [item.fields.customFields objectForKey:key];
    
    if ( field ) {
        [self dereferenceAndCopyToPasteboard:field.value item:item];
        
        NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
        [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, key]];
    }
}

- (void)copyTitle:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.title item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_title", @"Title")]];
}

- (void)copyUsername:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.username item:item];
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_username", @"Username")]];
}

- (void)copyEmail:(Node*)item {
    if ( !item ) {
        return;
    }
    
    [self dereferenceAndCopyToPasteboard:item.fields.email item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_email", @"Email")]];
}

- (void)copyUrl:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.url item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_url", @"URL")]];
}

- (void)copyNotes:(Node*)item {
    if(!item) return;
    
    [self dereferenceAndCopyToPasteboard:item.fields.notes item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_notes", @"Notes")]];
}

- (void)copyPassword:(Node*)item {
    if(!item || item.isGroup) {
        return;
    }
    
    [self dereferenceAndCopyToPasteboard:item.fields.password item:item];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_password", @"Password")]];
}

- (void)copyTotp:(Node*)item {
    if(!item || !item.fields.otpToken) {
        return;
    }
    
    NSString *password = item.fields.otpToken.password;
    [self copyConcealedAndMaybeMinimize:password];
    
    NSString* loc = NSLocalizedString(@"mac_field_copied_to_clipboard_fmt", @"'%@' %@ Copied");
    [self showPopupChangeToastNotification:[NSString stringWithFormat:loc, item.title, NSLocalizedString(@"generic_fieldname_totp", @"2FA")]];
}

- (IBAction)onLaunchUrl:(id)sender {
    Node* item = [self getSingleSelectedItem];
    
    [self.viewModel launchUrl:item];
}

- (void)copyUsernameAndPassword:(Node*)item {
    NSMutableArray<NSString*>* fields = NSMutableArray.array;
    
    [fields addObject:[self dereference:item.fields.username node:item]];
    [fields addObject:[self dereference:item.fields.password node:item]];
    
    NSString* allString = [fields componentsJoinedByString:@"\n"];
    [ClipboardManager.sharedInstance copyConcealedString:allString];
    
    NSString* loc = NSLocalizedString(@"generic_copied", @"Copied");
    [self showPopupChangeToastNotification:loc];
}

- (void)copyAllFields:(Node*)item {
    NSString* allString = [self.viewModel.commonModel getAllFieldsKeyValuesString:item.uuid];
    
    [ClipboardManager.sharedInstance copyConcealedString:allString];
    
    NSString* loc = NSLocalizedString(@"generic_copied", @"Copied");
    [self showPopupChangeToastNotification:loc];
}

- (void)showPopupChangeToastNotification:(NSString*)message {
    [self showToastNotification:message error:NO];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.window.isMiniaturized ) {
        slog(@"Not Showing Popup Change notification because window is miniaturized");
        return;
    }
    
    [self showToastNotification:message error:error yOffset:150.f];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error yOffset:(CGFloat)yOffset {
    if ( !self.viewModel.showChangeNotifications ) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{




        
        CIColor *color = [CIColor colorWithCGColor:NSColor.systemBlueColor.CGColor];
        NSColor* defaultColor = [NSColor colorWithDeviceRed:color.red green:color.green blue:color.blue alpha:color.alpha];
        
        NSColor *errorColor = [NSColor colorWithDeviceRed:1 green:0.55 blue:0.05 alpha:0.90];
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.contentViewController.view animated:YES];
        hud.labelText = message;
        hud.color = error ? errorColor : defaultColor;
        hud.mode = MBProgressHUDModeText;
        hud.margin = 12.f;
        hud.yOffset = 0.0f;
        hud.removeFromSuperViewOnHide = YES;
        hud.dismissible = YES;
        
        NSTimeInterval delay = error ? 3.0f : 0.5f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [hud hide:YES];
        });
    });
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self maybeDereference:text node:node maybe:YES];
}

- (NSString*)maybeDereference:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self.viewModel dereference:text node:node] : text;
}



- (void)maybeOnboardDatabase {
    [MacOnboardingManager beginDatabaseOnboardingWithParentViewController:self.contentViewController viewModel:self.viewModel completion:^{ }];
}



- (id)supplementalTargetForAction:(SEL)action sender:(id)sender {

    
    
    



    
    
    
    id target = [super supplementalTargetForAction:action sender:sender];
    
    if (target != nil) {
        return target;
    }
    
    NSViewController *childViewController = self.contentViewController;
    target = [NSApp targetForAction:action to:childViewController from:sender];
    
    if (![target respondsToSelector:action]) {
        target = [target supplementalTargetForAction:action sender:sender];
    }
    
    if ([target respondsToSelector:action]) {
        return target;
    }
    
    return nil;
}



- (IBAction)onExportDatabase:(id)sender {
    [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"generic_export_database", @"Export Database")
                    informativeText:NSLocalizedString(@"export_what_format_question", @"What format would you like to export to?")
                  option1AndDefault:@"CSV"
                            option2:@"KeePass"
                             window:self.window
                         completion:^(int response) {
        if ( response == 0 ) {
            [self onExportDatabaseAsCSV:nil];
        }
        else if ( response == 1 ) {
            [self onExportDatabaseAsKeePass2];
        }
    }];
}

- (IBAction)onExportSelectedItems:(id)sender {
    NSArray<Node*>* items = [self getSelectedItems];
    
    if ( items.count > 0 ) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"export_items_dialog_title", @"Export Items")
                        informativeText:NSLocalizedString(@"export_what_format_question", @"What format would you like to export to?")
                      option1AndDefault:@"CSV"
                                option2:@"KeePass"
                                 window:self.window
                             completion:^(int response) {
            if ( response == 0 ) {
                [self exportItemsAsCsv:items suggestedFilenameSuffix:@""];
            }
            else if ( response == 1 ) {
                [self exportItemsAsKeePass2:items suggestedFilenameSuffix:@""];
            }
        }];
    }
}

- (IBAction)onExportGroupFromSideBar:(id)sender {
    [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"export_group_dialog_title", @"Export Group")
                    informativeText:NSLocalizedString(@"export_what_format_question", @"What format would you like to export to?")
                  option1AndDefault:@"CSV"
                            option2:@"KeePass"
                             window:self.window
                         completion:^(int response) {
        if ( response == 0 ) {
            [self onExportGroupAsCsv:nil];
        }
        else if ( response == 1 ) {
            [self onExportGroupAsKeePass2:nil];
        }
    }];
}

- (void)onExportDatabaseAsKeePass2 {
    if ( self.viewModel == nil || self.viewModel.locked ) {
        return;
    }
    
    Node* root = self.viewModel.rootGroup;
    if ( self.viewModel.format == kKeePass1 && root.childGroups.count == 1 ) { 
        root = root.childGroups[0];
    }
    
    [self exportGroupAsKeePass2:root suggestedFilenameSuffix:@""];
}

- (void)onExportDatabaseAsCSV:(id)sender {
    [self exportGroupAsCsv:self.viewModel.database.effectiveRootGroup suggestedFilenameSuffix:@""];
}

- (void)onExportGroupAsCsv:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    
    if ( item && item.isGroup ) {
        [self exportGroupAsCsv:item suggestedFilenameSuffix:[NSString stringWithFormat:@"-%@", item.title]];
    }
}

- (void)onExportGroupAsKeePass2:(id)sender {
    Node* item = [self getSideBarSelectedItem];
    
    if ( item && item.isGroup ) {
        [self exportGroupAsKeePass2:item suggestedFilenameSuffix:[NSString stringWithFormat:@"-%@", item.title]];
    }
}

- (void)exportGroupAsKeePass2:(Node*)root suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    [self exportItemsAsKeePass2:@[root] suggestedFilenameSuffix:suggestedFilenameSuffix];
}

- (void)exportItemsAsKeePass2:(NSArray<Node*>*)items suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    DatabaseModel* newModel = [[DatabaseModel alloc] initWithFormat:kKeePass4
                                                compositeKeyFactors:self.viewModel.compositeKeyFactors
                                                           metadata:[UnifiedDatabaseMetadata withDefaultsForFormat:kKeePass4]
                                                               root:nil];
    if ( newModel == nil ) {
        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error") window:self.window];
        slog(@"🔴 Couldn't create model.");
        return;
    }
    
    
    
    
    NSArray<Node*>* clonedItems = [items map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return [obj cloneOrDuplicate:YES cloneUuid:YES cloneRecursive:YES newTitle:nil parentNode:newModel.effectiveRootGroup];
    }];

    for ( Node* ch in clonedItems ) {
        [newModel.effectiveRootGroup addChild:ch keePassGroupTitleRules:YES];
    }
    
    [self exportModelAsKeePass2:newModel suggestedFilenameSuffix:suggestedFilenameSuffix];
}

- (void)exportModelAsKeePass2:(DatabaseModel*)model suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    NSData* data = [Serializator expressToData:model format:kKeePass4];
    if ( data == nil ) {
        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error") window:self.window];
        slog(@"🔴 Couldn't serialize.");
        return;
    }

    
    
    NSSavePanel* panel = NSSavePanel.savePanel;
    
    if ( suggestedFilenameSuffix.length ) {
        NSURL* fileUrl = self.viewModel.databaseMetadata.fileUrl;
        NSString* withoutExtension = [fileUrl.path.lastPathComponent stringByDeletingPathExtension];
        
        panel.nameFieldStringValue = [NSString stringWithFormat:@"%@%@.kdbx", withoutExtension, suggestedFilenameSuffix];
    }
    else {
        panel.nameFieldStringValue = [NSString stringWithFormat:@"%@.kdbx", self.viewModel.databaseMetadata.exportFileName];
    }
    
    if ( [panel runModal] == NSModalResponseOK ) {
        NSError* error;
        
        if (! [data writeToURL:panel.URL options:kNilOptions error:&error] ) {
            slog(@"🔴 Could not write to file: [%@]", error);
            [MacAlerts error:error window:self.window];
        }
        else {
            [MacAlerts info:NSLocalizedString(@"generic_done", @"Done") window:self.window];
        }
    }
}

- (void)exportGroupAsCsv:(Node*)group suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    NSArray<Node*>* nodes = [group filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
    
    return [self exportItemsAsCsv:nodes suggestedFilenameSuffix:suggestedFilenameSuffix];
}

- (void)exportItemsAsCsv:(NSArray<Node*>*)items suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    [self requestVerifyMasterCredentials:NSLocalizedString(@"verify_creds_before_plaintext_export_bio_message_suffix", @"verify existing credentials before you can export in plaintext.")
                       manualCkfHeadline:NSLocalizedString(@"verify_creds_headline", @"Verify Master Credentials")
                    manualCkfSubheadline:NSLocalizedString(@"verify_creds_before_plaintext_export_subhead", @"For security reasons your current master credentials must be verified before you can export in plaintext.")
                              completion:^(BOOL userCancelled, BOOL verified, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( error ) {
                [MacAlerts error:error window:self.window];
            }
            else if ( userCancelled ) {
                
            }
            else if ( verified ) {
                [self exportItemsAsPlaintextCsv:items suggestedFilenameSuffix:suggestedFilenameSuffix];
            }
            else {
                [self onLock:nil];
                
                [MacAlerts info:NSLocalizedString(@"credentials_incorrect_database_locked", @"Those credentials are incorrect and your database has now been locked for security reasons.")
                         window:self.window];
            }
        });
    }];
}

- (void)exportItemsAsPlaintextCsv:(NSArray<Node*>*)items suggestedFilenameSuffix:(NSString*)suggestedFilenameSuffix {
    NSData* data = [Csv getNodesAsCsv:items];
    if ( !data ) {
        [MacAlerts error:nil window:self.window];
        return;
    }
    
    NSSavePanel* savePanel = NSSavePanel.savePanel;
    
    if ( suggestedFilenameSuffix.length ) {
        NSURL* fileUrl = self.viewModel.databaseMetadata.fileUrl;
        NSString* withoutExtension = [fileUrl.path.lastPathComponent stringByDeletingPathExtension];
        
        savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@%@.csv", withoutExtension, suggestedFilenameSuffix];
    }
    else {
        savePanel.nameFieldStringValue = [NSString stringWithFormat:@"%@.csv", self.viewModel.databaseMetadata.exportFileName];
    }
    
    if ( [savePanel runModal] == NSModalResponseOK ) {
        NSURL* url = savePanel.URL;
        NSError* error;
        if (! [data writeToFile:url.path options:kNilOptions error:&error] ) {
            [MacAlerts error:error window:self.window];
        }
    }
}



- (IBAction)onSaveDatabaseAs:(id)sender {
    MacDatabasePreferences* database = self.viewModel.databaseMetadata;
    
    NSSavePanel* panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = database.exportFileName;
    
    if ( [panel runModal] != NSModalResponseOK ) {
        return;
    }
    
    NSURL* dest = panel.URL;
    
    [self saveDatabaseAs:dest];
}

- (void)saveDatabaseAs:(NSURL*)dest {
    NSURL* src = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.viewModel.databaseMetadata.uuid];
    slog(@"Export [%@] => [%@]", src, dest);
    
    if ( !src ) {
        [MacAlerts info:NSLocalizedString(@"open_sequence_couldnt_open_local_message", "Could not open Strongbox's local copy of this database. A online sync is required.")
                 window:self.window];
    }
    else {
        NSError* errr;
        BOOL copy;
        
        if ( [NSFileManager.defaultManager fileExistsAtPath:dest.path] ) {
            NSDictionary* attr = [NSFileManager.defaultManager attributesOfItemAtPath:src.path error:nil];
            NSData* data = [NSData dataWithContentsOfFile:src.path];
            copy = [NSFileManager.defaultManager createFileAtPath:dest.path contents:data attributes:attr];
        }
        else {
            copy = [NSFileManager.defaultManager copyItemAtURL:src toURL:dest error:&errr];
        }
        
        if ( !copy ) {
            [MacAlerts error:errr window:self.window];
        }
        else {
            [MacAlerts info:NSLocalizedString(@"export_vc_export_successful_title", @"Export Successful")
                     window:self.window];
        }
    }
}



- (IBAction)onCompareAndMerge:(id)sender {
    CompareAndMergeWizard* wizard = [CompareAndMergeWizard fromStoryboard];
    
    __weak WindowController* weakSelf = self;
    
    wizard.firstModel = self.viewModel;
    wizard.onSelectedSecondDatabase = ^(DatabaseModel * secondModel, MacDatabasePreferences * secondModelMetadata, NSURL * secondModelUrl) {
        [weakSelf compare:secondModel secondModelMetadata:secondModelMetadata secondModelUrl:secondModelUrl];
    };

    [self.contentViewController presentViewControllerAsSheet:wizard];
}
    
- (void)compare:(DatabaseModel*)secondModel
secondModelMetadata:(MacDatabasePreferences*)secondModelMetadata
 secondModelUrl:(NSURL*)secondModelUrl {
    CompareDatabasesViewController* vc = [CompareDatabasesViewController fromStoryboard];
    
    vc.firstModel = self.viewModel.commonModel;
    vc.secondModel = secondModel;
    vc.secondModelTitle = secondModelMetadata ? secondModelMetadata.nickName : secondModelUrl.absoluteString;
    
    __weak WindowController* weakSelf = self;
    
    vc.onDone = ^(BOOL mergeRequested, BOOL synchronize) {
        if ( mergeRequested ) {
            [weakSelf onMergeOrSynchronize:secondModel
                       secondModelMetadata:secondModelMetadata
                            secondModelUrl:secondModelUrl
                               synchronize:synchronize];
        }
    };
    
    [self.contentViewController presentViewControllerAsSheet:vc];
}

- (void)onMergeOrSynchronize:(DatabaseModel*)secondModel
         secondModelMetadata:(MacDatabasePreferences*)secondModelMetadata
              secondModelUrl:(NSURL*)secondModelUrl
                 synchronize:(BOOL)synchronize {
    if ( self.viewModel.readOnly || (synchronize && secondModelMetadata != nil && secondModelMetadata.readOnly ) ) {
        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error")
        informativeText:NSLocalizedString(@"merge_cannot_merge_because_read_only", @"Cannot Merge because your database is Read-Only")
                 window:self.window
             completion:nil];
        return;
    }
    
    
    
    DatabaseModel* merged = [self.viewModel.database clone];
    DatabaseMerger* syncer = [DatabaseMerger mergerFor:merged theirs:secondModel];
    BOOL success = [syncer merge];

    if ( !success ) {
        slog(@"🔴 Unsuccessful Merge/Synchronize");
        
        [MacAlerts info:NSLocalizedString(@"generic_error", @"Error")
        informativeText:NSLocalizedString(@"merge_view_merge_title_error", @"There was an problem merging this database.")
                 window:self.window
             completion:nil];
    }
    else {
        [self.viewModel.commonModel replaceEntireUnderlyingDatabaseWith:merged];
        
        
        
        
        NSUUID* updateId = NSUUID.UUID;
        slog(@"WindowController::synchronizeSecondDatabase start [%@]", updateId);
        self.viewModel.commonModel.metadata.asyncUpdateId = updateId;

        [self.viewModel.commonModel asyncUpdateAndSync:^(AsyncJobResult * _Nonnull result) {
            if ( [updateId isEqualTo:self.viewModel.commonModel.metadata.asyncUpdateId] ) {
                self.viewModel.commonModel.metadata.asyncUpdateId = nil;
            }
            else {
                slog(@"Not clearing asyncUpdateId as not the same as expected...");
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if ( result.error ) {
                    [MacAlerts error:result.error window:self.window];
                }
                else if ( !result.userCancelled ) {
                    if ( synchronize ) {
                        [self synchronizeSecondDatabase:self.viewModel.database secondModelMetadata:secondModelMetadata secondModelUrl:secondModelUrl];
                    }
                    else {
                        [self messageMergeDoneSuccess];
                    }
                }
            });
            
            [self.viewModel.commonModel asyncSync]; 
        }];
    }
}

- (void)synchronizeSecondDatabase:(DatabaseModel*)mergedDatabase
              secondModelMetadata:(MacDatabasePreferences*)secondModelMetadata
                   secondModelUrl:(NSURL*)secondModelUrl {
    if ( secondModelMetadata ) {
        Model* model = [[Model alloc] initWithDatabase:mergedDatabase metaData:secondModelMetadata forcedReadOnly:NO isAutoFill:NO offlineMode:NO];

        
        
        
        NSUUID* updateId = NSUUID.UUID;
        slog(@"WindowController::synchronizeSecondDatabase start [%@]", updateId);
        model.metadata.asyncUpdateId = updateId;

        [model asyncUpdateAndSync:^(AsyncJobResult * _Nonnull result) {
            if ( [updateId isEqualTo:model.metadata.asyncUpdateId] ) {
                model.metadata.asyncUpdateId = nil;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( result.error ) {
                    [MacAlerts error:result.error window:self.window];
                }
                else if ( !result.userCancelled ) {
                    [self messageMergeDoneSuccess];
                }
            });
        }];
    }
    else {
        [self encryptForMerge:mergedDatabase completion:^(NSData *data) {
            if ( data ) {
                NSError* error;
                if ( ![data writeToURL:secondModelUrl options:kNilOptions error:&error] ) {
                    [MacAlerts error:error window:self.window];
                }
                else {
                    [self messageMergeDoneSuccess];
                }
            }
        }];
    }
}

- (void)encryptForMerge:(DatabaseModel*)merged completion:(void (^)(NSData* data))completion {
    [macOSSpinnerUI.sharedInstance show:NSLocalizedString(@"generic_encrypting", @"Encrypting") viewController:self.contentViewController];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory]; 
        [outputStream open];
        
        [Serializator getAsData:merged
                         format:merged.originalFormat
                   outputStream:outputStream
                     completion:^(BOOL userCancelled, NSString * _Nullable debugXml, NSError * _Nullable error) {
            
            [outputStream close];
            NSData* mergedData = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];

            dispatch_async(dispatch_get_main_queue(), ^{
                [macOSSpinnerUI.sharedInstance dismiss];
                
                if (userCancelled) {
                    completion ( nil );
                }
                else if (error) {
                    [MacAlerts error:error window:self.window];
                    completion ( nil );
                }
                else {
                    completion ( mergedData );
                }
            });
        }];
    });
}

- (void)messageMergeDoneSuccess {
    [MacAlerts info:NSLocalizedString(@"merge_view_merge_title_success", @"Merge Successful")
    informativeText:NSLocalizedString(@"merge_view_merge_message_success", @"The Merge was successful and your database is now up to date.")
             window:self.window
         completion:nil];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {


    if ( !Settings.sharedInstance.hasAskedAboutDatabaseOpenInBackground && self.viewModel && !self.viewModel.locked ) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"mac_on_window_close_action_title", @"Lock Database?")
                        informativeText:NSLocalizedString(@"mac_on_window_close_action_message", @"Strongbox can keep your databases open in the background or it can lock them immediately when you close the window.\n\nWhat would you like Strongbox to do when you close a Database window?")
                      option1AndDefault:NSLocalizedString(@"mac_on_window_close_action_option_keep_unlocked", @"Keep Database Unlocked")
                                option2:NSLocalizedString(@"mac_on_window_close_action_lock_immediately", @"Lock Database Immediately")
                                 window:self.window
                             completion:^(int response) {
            if ( response == 0 ) { 
                Settings.sharedInstance.hasAskedAboutDatabaseOpenInBackground = YES;
                Settings.sharedInstance.lockDatabaseOnWindowClose = NO;
            }
            else if ( response == 1 ) { 
                Settings.sharedInstance.hasAskedAboutDatabaseOpenInBackground = YES;
                Settings.sharedInstance.lockDatabaseOnWindowClose = YES;
            }
            
            [self close];
        }];
        
        return NO;
    }
    else {
        return YES;
    }
}

- (void)close {
    [super close];
    
    slog(@"✅ Closing WindowController!");
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    [self synchronizeWindowTitleWithDocumentName];
}

@end
