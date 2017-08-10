//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if(self.model != nil) {
        [self bindFromModel];
    }
    else {
        self.textField.stringValue = @"<No Model>";
    }
}

-(void)setModel:(ViewModel *)model {
    _model = model;
    
    [self bindFromModel];
}

- (void)bindFromModel {
    if(self.model == nil) {
        self.textField.stringValue = @"<NO MODEL>";
        
        self.stackViewLockControls.hidden = YES;
        self.stackViewUnlocked.hidden = NO;

        [self.outlineView reloadData];
        return;
    }
    
    self.textField.stringValue = self.model.locked ? @"Locked!" : @"Unlocked";
    
    if(self.model.locked) {
        self.stackViewLockControls.hidden = NO;
        self.stackViewUnlocked.hidden = YES;
    }
    else {
        self.stackViewLockControls.hidden = YES;
        self.stackViewUnlocked.hidden = NO;
    }
    
    [self.outlineView reloadData];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.model || self.model.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<SafeItemViewModel*> *items = [self.model.unlockedDbModel getItemsForGroup:nil];
        
        return items.count > 0;
    }
    else {
        SafeItemViewModel *it = (SafeItemViewModel*)item;
        
        if(it.isGroup) {
            NSArray<SafeItemViewModel*> *items = [self.model.unlockedDbModel getItemsForGroup:it.group];
            
            return items.count > 0;
        }
        else {
            return NO;
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if(!self.model || self.model.locked) {
        return 0;
    }
    
    Group* group = (item == nil) ? nil : ((SafeItemViewModel*)item).group;
    
    NSArray<SafeItemViewModel*> *items = [self.model.unlockedDbModel getItemsForGroup:group];
    
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    Group* group = (item == nil) ? nil : ((SafeItemViewModel*)item).group;
    
    NSArray<SafeItemViewModel*> *items = [self.model.unlockedDbModel getItemsForGroup:group];
    
    return items[index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item
{
    return item;
}

/////////////////////////////

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
    NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"CellIdentifier" owner:self];

    SafeItemViewModel *it = (SafeItemViewModel*)item;
    
    cell.textField.stringValue = it.title;

    return cell;
}

- (IBAction)onUnlock:(id)sender {
    //    NSError *error;
    //    self.model = [[CoreModel alloc] initExistingWithDataAndPassword:data password:password error:&error];
    
    if(self.model && self.model.locked) {
        NSError *error;
        if([self.model unlock:self.textFieldPassword.stringValue error:&error]) {
            [self bindFromModel];
        }
        else {
            // TODO: Message?
        }
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        [self.model lock];
        
        [self bindFromModel];
    }
}

- (IBAction)onOutlineViewDoubleClick:(id)sender {
    SafeItemViewModel *item = [sender itemAtRow:[sender clickedRow]];
    
    if ([sender isItemExpanded:item]) {
        [sender collapseItem:item];
    }
    else {
        [sender expandItem:item];
    }
}

@end
