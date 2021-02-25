//
//  AddDatabaseSelectStorageVC.m
//  MacBox
//
//  Created by Strongbox on 03/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "AddDatabaseSelectStorageVC.h"
#import "SafeStorageProvider.h"
#import "MacAlerts.h"
#import "SafeStorageProviderFactory.h"
#import "Utils.h"

@interface AddDatabaseSelectStorageVC () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSButton *buttonSelect;

@property BOOL hasLoaded;
@property NSMutableDictionary<NSString*, NSArray<StorageBrowserItem*>*>* itemsCache;

@end

static NSString * const kRootItemCacheKey = @"AddDatabaseSelectStorageVC-Root-Item-Cache-Key-MMcG";
static NSString * const kLoadingItemIdentifier = @"AddDatabaseSelectStorageVC-Loading-Item-Key-MMcG";
static NSString * const kLoadingItemErrorIdentifier = @"AddDatabaseSelectStorageVC-Loading-Item-ERROR-MMcG";

@implementation AddDatabaseSelectStorageVC

+ (instancetype)newViewController {
    NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"AddDatabaseSelectStorageProvider" bundle:nil];
    AddDatabaseSelectStorageVC* sharedInstance = [storyboard instantiateInitialController];
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
}

- (void)loadItems:(StorageBrowserItem*)sbi {
    NSLog(@"loadItems: [%@]", sbi);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self.provider list:sbi.providerData
             viewController:self
                 completion:^(BOOL userCancelled, NSArray<StorageBrowserItem *> * _Nonnull items, const NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( userCancelled ) {
                    [self onCancel:nil];
                }
                else {
                    NSString* key = [self getCacheKey:sbi];
                    if ( error ) {
                        NSLog(@"error %@", error);
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
            });
        }];
    });
}

- (NSString*)getCacheKey:(StorageBrowserItem*)sbi {
    NSString* key = sbi ? sbi.identifier : kRootItemCacheKey;
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
    if (@available(macOS 10.14, *)) {
        cell.imageView.contentTintColor = nil;
    }
    
    if ( [sbi.identifier isEqualToString:kLoadingItemIdentifier] ) {
        cell.imageView.image = [NSImage imageNamed:@"syncronize"];
    }
    else if ([sbi.identifier isEqualToString:kLoadingItemErrorIdentifier]) {
        cell.imageView.image = [NSImage imageNamed:@"cancel"];
        if (@available(macOS 10.14, *)) {
            cell.imageView.contentTintColor = NSColor.systemRedColor;
        }
    }
    else {
        cell.imageView.image = sbi.folder ?  [NSImage imageNamed:@"KPXC_C48_Folder"] : [NSImage imageNamed:@"KPXC_C22_ASCII"];
    }
    
    if ( sbi.name.length > 0 && [[sbi.name substringToIndex:1] isEqualToString:@"."] ) {
        cell.alphaValue = 0.7f;
    }
    
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    [self bindUi];
}

- (void)bindUi {
    self.buttonSelect.enabled = [self isValidItemSelected];
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

    if ( [item.identifier isEqualToString:kLoadingItemIdentifier] ||
         [item.identifier isEqualToString:kLoadingItemErrorIdentifier]) {
        return NO;
    }
    
    if ( item.folder ) {
        return NO;
    }
    
    return YES;
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
