//
//  AddDatabaseSelectStorageVC.m
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SelectStorageLocationVC.h"
#import "SafeStorageProvider.h"
#import "MacAlerts.h"
#import "SafeStorageProviderFactory.h"
#import "Utils.h"

@interface SelectStorageLocationVC () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSButton *buttonSelect;

@property BOOL hasLoaded;
@property NSMutableDictionary<NSString*, NSArray<StorageBrowserItem*>*>* itemsCache;

@property (weak) IBOutlet NSTextField *labelTitle;
@property (weak) IBOutlet NSTextField *labelSubtitle;
@property (weak) IBOutlet NSButton *buttonSelectRoot;

@end

static NSString * const kRootItemCacheKey = @"AddDatabaseSelectStorageVC-Root-Item-Cache-Key-MMcG";
static NSString * const kLoadingItemIdentifier = @"AddDatabaseSelectStorageVC-Loading-Item-Key-MMcG";
static NSString * const kLoadingItemErrorIdentifier = @"AddDatabaseSelectStorageVC-Loading-Item-ERROR-MMcG";

@implementation SelectStorageLocationVC

+ (instancetype)newViewController {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"AddDatabaseSelectStorageProvider" bundle:nil];
    SelectStorageLocationVC* sharedInstance = [storyboard instantiateInitialController];
    return sharedInstance;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    if(!self.hasLoaded) {
        self.hasLoaded = YES;

        self.itemsCache = NSMutableDictionary.dictionary;
        
        [self setupUi];
        [self bindUi];
    }
}

- (void)setupUi {
    self.outlineView.dataSource = self;
    self.outlineView.delegate = self;
    
    self.outlineView.doubleAction = @selector(onSelect:);
    
    if ( self.createMode ) {
        self.labelTitle.stringValue = NSLocalizedString(@"choose_storage_loc", @"Choose Storage Location");
        self.labelSubtitle.stringValue = NSLocalizedString(@"nav_to_storage_and_select", @"Please navigate to where you would like to store your database and click 'Select'.");
    }
    
    self.buttonSelectRoot.hidden = !self.createMode || self.disallowCreateAtRoot;
}

- (void)bindUi {
    self.buttonSelect.enabled = [self isValidItemSelected];
}

- (void)loadItems:(StorageBrowserItem*)sbi {
    
    
    __weak SelectStorageLocationVC* weakSelf = self;
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [weakSelf.provider list:sbi ? sbi.providerData : self.rootBrowserItem.providerData
                 viewController:weakSelf
                     completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> * _Nonnull items, const NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf onListComplete:sbi userCancelled:userCancelled items:items error:error];
            });
        }];
    });
}

- (void)onListComplete:(StorageBrowserItem*)sbi userCancelled:(BOOL)userCancelled items:(NSArray<StorageBrowserItem *> * _Nonnull)items error:(const NSError * _Nonnull)error {
    if ( userCancelled ) {
        [self onCancel:nil];
    }
    else {
        NSString* key = [self getCacheKey:sbi];
        
        if ( error ) {
            slog(@"error %@", error);
            self.itemsCache[key] = @[[StorageBrowserItem itemWithName:error.description identifier:kLoadingItemErrorIdentifier folder:NO providerData:nil]];
        }
        else {
            
            
            NSArray<StorageBrowserItem*>* sorted = [items sortedArrayUsingComparator:^NSComparisonResult(StorageBrowserItem*  _Nonnull obj1, StorageBrowserItem*  _Nonnull obj2) {
                if(obj1.folder && !obj2.folder) {
                    return NSOrderedAscending;
                }
                else if(!obj1.folder && obj2.folder) {
                    return NSOrderedDescending;
                }
                else {
                    return finderStringCompare(obj1.name, obj2.name);
                }
            }];
            
            self.itemsCache[key] = sorted;
        }
        
        [self.outlineView reloadItem:sbi reloadChildren:YES];
    }
}

- (NSString*)getCacheKey:(StorageBrowserItem*)sbi {
    NSString* key = sbi ? sbi.identifier : kRootItemCacheKey;
    
    if ( key == nil ) {
        slog(@"🔴 getCacheKey nil key!!");
    }
    
    return key;
}



- (NSArray<StorageBrowserItem*>*)getChildItems:(StorageBrowserItem*)sbi {
    NSString* key = [self getCacheKey:sbi];
    NSArray<StorageBrowserItem*>* ret = self.itemsCache[key];
    
    return ret;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    NSArray<StorageBrowserItem*>* ret = [self getChildItems:item];



    if (!ret) {
        [self loadItems:item];
        return 1; 
    }
    else {
        return ret.count;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {

    
    NSArray<StorageBrowserItem*>* ret = [self getChildItems:item];
    
    if (!ret) {
        return [StorageBrowserItem itemWithName:NSLocalizedString(@"generic_loading", @"Loading...") identifier:kLoadingItemIdentifier folder:NO providerData:nil];
    }
    else {
        return ret[index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    StorageBrowserItem* sbi = item;
    
    NSArray* children = [self getChildItems:item];
    
    return sbi.folder && !(children && children.count == 0);
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {

    
    NSTableCellView* cell = (NSTableCellView*)[self.outlineView makeViewWithIdentifier:@"storageBrowserCellIdentifier" owner:self];
    StorageBrowserItem *sbi = item;

    cell.textField.stringValue = sbi.name;
    cell.imageView.contentTintColor = nil;
    
    if ( [sbi.identifier isEqualToString:kLoadingItemIdentifier] ) {
        cell.imageView.image = [NSImage imageNamed:@"syncronize"];
    }
    else if ([sbi.identifier isEqualToString:kLoadingItemErrorIdentifier]) {
        cell.imageView.image = [NSImage imageNamed:@"cancel"];
        cell.imageView.contentTintColor = NSColor.systemRedColor;
    }
    else {
        cell.imageView.image = sbi.folder ?  [NSImage imageNamed:@"KPXC_C48_Folder"] : [NSImage imageNamed:@"KPXC_C22_ASCII"];
    }
    
    if ( sbi.name.length > 0 && [[sbi.name substringToIndex:1] isEqualToString:@"."] ) {
        cell.alphaValue = 0.7f;
    }
    
    BOOL isFile = !sbi.folder;
    BOOL enabled = !sbi.disabled && ((!self.createMode) || (!isFile && self.createMode));
    
    cell.textField.enabled = enabled;
    cell.textField.textColor = enabled ? nil : NSColor.secondaryLabelColor;
    cell.imageView.enabled = enabled;
    
    return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    StorageBrowserItem* sbi = item;

    BOOL isFile = !sbi.folder;
    BOOL shouldSelect = !sbi.disabled && ((!self.createMode) || (!isFile && self.createMode));

    return shouldSelect;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (IBAction)onCancel:(id)sender {
    self.onDone(NO, nil);
    [self.presentingViewController dismissViewController:self];
}

- (BOOL)isValidItemSelected {
    if ( self.outlineView.selectedRow == -1 ) {
        return NO;
    }
    
    StorageBrowserItem* item = [self.outlineView itemAtRow:self.outlineView.selectedRow];
    
    return [self isValidItem:item];
}

- (BOOL)isValidItem:(StorageBrowserItem*)item {
    if ( [item.identifier isEqualToString:kLoadingItemIdentifier] ||
         [item.identifier isEqualToString:kLoadingItemErrorIdentifier]) {
        return NO;
    }
        
    if ( item.folder ) {
        return self.createMode;
    }
    else {
        return !self.createMode;
    }
}

- (IBAction)onSelectRoot:(id)sender {
    self.onDone(YES, nil);
    [self.presentingViewController dismissViewController:self];
}

- (IBAction)onSelect:(id)sender {
    if (![self isValidItemSelected]) {
        return;
    }

    StorageBrowserItem* item = [self.outlineView itemAtRow:self.outlineView.selectedRow];

    self.onDone(YES, item);
    [self.presentingViewController dismissViewController:self];
}

@end
