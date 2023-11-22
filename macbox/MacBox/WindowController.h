//
//  WindowController.h
//  MacBox
//
//  Created by Mark on 07/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface WindowController : NSWindowController <NSMenuItemValidation, NSMenuDelegate>

- (void)copyConcealedAndMaybeMinimize:(NSString*)string;
- (void)changeContentView;
- (BOOL)placeItemsOnPasteboard:(NSPasteboard*)pasteboard items:(NSArray<Node*>*)items;
- (NSUInteger)pasteItemsFromPasteboard:(NSPasteboard*)pasteboard
                       destinationItem:(Node*)destinationItem
                              internal:(BOOL)internal
                                 clear:(BOOL)clear;



- (IBAction)onCopyPassword:(id _Nullable)sender;
- (IBAction)onCopyUsername:(id)sender;
- (IBAction)onCopyEmail:(id)sender;
- (IBAction)onCopyUrl:(id)sender;
- (IBAction)onCopyNotes:(id)sender;
- (IBAction)onCopyTotp:(id)sender;


- (void)onDeleteItems:(NSArray<Node*>*)items
           completion:( void (^ _Nullable)(BOOL success) )completion;

- (IBAction)onPrintGroupFromSideBar:(id)sender;
- (IBAction)onExportGroupFromSideBar:(id)sender;

- (IBAction)onGeneralDatabaseSettings:(id)sender;
- (IBAction)onConvenienceUnlockProperties:(id)sender;
- (IBAction)onDatabaseAutoFillSettings:(id)sender;
- (IBAction)onDatabaseEncryptionSettings:(id)sender;
- (IBAction)onChangeMasterPassword:(id)sender;
- (IBAction)onEmptyRecycleBin:(id)sender;
- (IBAction)onToggleFavouriteItemInSideBar:(id)sender;
- (IBAction)onSideBarCreateGroup:(id)sender;
- (IBAction)onSideBarDuplicateItem:(id)sender;
- (IBAction)onSideBarFindFavIcons:(id)sender;
- (IBAction)onSideBarItemProperties:(id)sender;
- (IBAction)onDeleteSideBarItem:(id)sender;
- (IBAction)onSetSideBarItemIcon:(id)sender;
- (IBAction)onRenameSideBarItem:(id)sender;

- (Node*_Nullable)getSingleSelectedItem; 

- (void)onLock:(id _Nullable)sender;

@end

NS_ASSUME_NONNULL_END
