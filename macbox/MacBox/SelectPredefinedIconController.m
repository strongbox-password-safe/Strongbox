//
//  SelectPredefinedIconController.m
//  Strongbox
//
//  Created by Mark on 25/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SelectPredefinedIconController.h"
#import "PredefinedKeePassIcon.h"
#import "Utils.h"
#import "MacAlerts.h"
#import "CollectionViewHeader.h"
#import "NodeIconHelper.h"

@interface SelectPredefinedIconController () <NSCollectionViewDataSource, NSCollectionViewDelegate>

@property (weak) IBOutlet NSCollectionView *collectionView;
@property (weak) IBOutlet NSButton *buttonSelectFile;
@property (weak) IBOutlet NSButton *buttonFindFavIcons;
@property NSArray<NSImage*>* predefinedIcons;
@property NSArray<NodeIcon*> *customIcons;

@end

@implementation SelectPredefinedIconController

- (void)windowDidLoad {
    [super windowDidLoad];

    self.predefinedIcons = [NodeIconHelper getIconSet:self.iconSet];

    if ( self.iconPool ) {
        self.customIcons = [self.iconPool sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NodeIcon *n1 = obj1;
            NodeIcon *n2 = obj2;
            
            return [@(n1.preferredOrder) compare:@(n2.preferredOrder)];
        }];
    }
    else {
        self.customIcons = @[];
    }

    
    self.buttonSelectFile.hidden = self.hideSelectFile;
    self.buttonFindFavIcons.hidden = self.hideFavIconButton;
        
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
}

- (BOOL)hasCustomIcons {
    return (self.customIcons && self.customIcons.count);
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return [self hasCustomIcons] ? 2 : 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self hasCustomIcons] && section == 0 ? self.customIcons.count : self.predefinedIcons.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    PredefinedKeePassIcon *item = [self.collectionView makeItemWithIdentifier:@"PredefinedKeePassIcon" forIndexPath:indexPath];
    
    if([self hasCustomIcons] && indexPath.section == 0) {
        NodeIcon* icon = self.customIcons[indexPath.item];
        item.icon.image = [NodeIconHelper getNodeIcon:icon predefinedIconSet:self.iconSet];
    }
    else {
        item.icon.image = self.predefinedIcons[indexPath.item];
    }
    
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    if(indexPaths.count == 1) {
        slog(@"Selected: [%@]", indexPaths.anyObject);
        NSIndexPath *indexPath = indexPaths.anyObject;
        
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
        
        if([self hasCustomIcons] && indexPath.section == 0) {
            NodeIcon* icon = self.customIcons[indexPath.item];
            self.onSelectedItem(icon, NO);
        }
        else {
            self.onSelectedItem([NodeIcon withPreset:indexPath.item], NO);
        }
        
    }
}

- (IBAction)onUseDefault:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    self.onSelectedItem(nil, NO);
}

- (IBAction)onCancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)onSelectFromFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
            slog(@"%@", openPanel.URL.path);
            
            NSError* error;
            NSData* data = [NSData dataWithContentsOfFile:openPanel.URL.path options:kNilOptions error:&error];
            
            if(!data) {
                slog(@"Could not read file at %@. Error: %@", openPanel.URL, error);
                
                NSString* loc = NSLocalizedString(@"mac_could_not_open_this_file", @"Could not open this file.");
                [MacAlerts error:loc error:error window:self.window];
                return;
            }

            [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
            
            
            
            
            self.onSelectedItem([NodeIcon withCustom:data], NO);
        }
    }];
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind
               atIndexPath:(NSIndexPath *)indexPath {
    if (kind == NSCollectionElementKindSectionHeader) {
        CollectionViewHeader* ret = [self.collectionView makeSupplementaryViewOfKind:kind withIdentifier:@"CollectionViewHeader" forIndexPath:indexPath];
        
        NSString* loc = [self hasCustomIcons] && indexPath.section == 0 ?
            NSLocalizedString(@"mac_database_icons", @"Database Icons") :
            NSLocalizedString(@"mac_keepass_icons", @"KeePass Icons");

        ret.labelTitle.stringValue = loc;
        
        return ret;
    }
    
    return NSView.new;
}

- (IBAction)onFindFavIcons:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    self.onSelectedItem(nil, YES);
}

@end
