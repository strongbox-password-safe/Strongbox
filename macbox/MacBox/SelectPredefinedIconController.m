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
#import "KeePassPredefinedIcons.h"
#import "Alerts.h"
#import "CollectionViewHeader.h"
#import "MacNodeIconHelper.h"

@interface SelectPredefinedIconController () <NSCollectionViewDataSource, NSCollectionViewDelegate>

@property (weak) IBOutlet NSCollectionView *collectionView;
@property (weak) IBOutlet NSButton *buttonSelectFile;

@end

@implementation SelectPredefinedIconController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;

    self.buttonSelectFile.hidden = self.hideSelectFile;
}

- (BOOL)hasCustomIcons {
    return (self.customIcons && self.customIcons.count);
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return [self hasCustomIcons] ? 2 : 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self hasCustomIcons] && section == 0 ? self.customIcons.count : KeePassPredefinedIcons.icons.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    PredefinedKeePassIcon *item = [self.collectionView makeItemWithIdentifier:@"PredefinedKeePassIcon" forIndexPath:indexPath];
    
    if([self hasCustomIcons] && indexPath.section == 0) {
        NSUUID* uuid = self.customIcons.allKeys[indexPath.item];
        
        item.icon.image = [MacNodeIconHelper getCustomIcon:uuid customIcons:self.customIcons];
    }
    else {
        item.icon.image = KeePassPredefinedIcons.icons[indexPath.item];
    }
    
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    if(indexPaths.count == 1) {
        NSLog(@"Selected: [%@]", indexPaths.anyObject);
        NSIndexPath *indexPath = indexPaths.anyObject;
        
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
        
        if([self hasCustomIcons] && indexPath.section == 0) {
            NSUUID* uuid = self.customIcons.allKeys[indexPath.item];
            self.onSelectedItem(nil, nil, uuid);
        }
        else {
            self.onSelectedItem(@(indexPath.item), nil, nil);
        }
        
    }
}

- (IBAction)onUseDefault:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    self.onSelectedItem(@(-1), nil, nil);
}

- (IBAction)onCancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)onSelectFromFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"%@", openPanel.URL.path);
            
            NSError* error;
            NSData* data = [NSData dataWithContentsOfFile:openPanel.URL.path options:kNilOptions error:&error];
            
            if(!data) {
                NSLog(@"Could not read file at %@. Error: %@", openPanel.URL, error);
                [Alerts error:@"Could not open this file." error:error window:self.window];
                return;
            }

            [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
            self.onSelectedItem(nil, data, nil);
        }
    }];
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == NSCollectionElementKindSectionHeader) {
        CollectionViewHeader* ret = [self.collectionView makeSupplementaryViewOfKind:kind withIdentifier:@"CollectionViewHeader" forIndexPath:indexPath];
        
        
        ret.labelTitle.stringValue = [self hasCustomIcons] && indexPath.section == 0 ? @"Database Icons" : @"KeePass Icons";
        
        return ret;
    }
    
    return nil;
}

@end
