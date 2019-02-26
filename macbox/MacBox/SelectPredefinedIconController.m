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

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return KeePassPredefinedIcons.icons.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    PredefinedKeePassIcon *item = [self.collectionView makeItemWithIdentifier:@"PredefinedKeePassIcon" forIndexPath:indexPath];
    
    item.icon.image = KeePassPredefinedIcons.icons[indexPath.item];
    
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    if(indexPaths.count == 1) {
        NSLog(@"Selected: [%@]", indexPaths.anyObject);
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
        self.onSelectedItem(@(indexPaths.anyObject.item), nil);
    }
}

- (IBAction)onUseDefault:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    self.onSelectedItem(@(-1), nil);
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
            self.onSelectedItem(nil, data);
        }
    }];
}

@end
