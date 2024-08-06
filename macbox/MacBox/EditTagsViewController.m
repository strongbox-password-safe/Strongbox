//
//  EditTagsViewController.m
//  MacBox
//
//  Created by Strongbox on 07/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "EditTagsViewController.h"
#import "MacAlerts.h"
#import "SBLog.h"

@interface EditTagsViewController () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSButton *buttonRemove;
@property (weak) IBOutlet NSButton *buttonAdd;
@property (weak) IBOutlet NSTableView *tableView;

@property BOOL hasLoaded;

@end

@implementation EditTagsViewController

- (void)viewWillAppear {
    [super viewWillAppear];

    if(!self.hasLoaded) {
        self.hasLoaded = YES;
        [self doInitialSetup];
    }
    
    [self bindUi];
}

- (void)doInitialSetup {
    self.view.window.delegate = self;

    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

- (void)bindUi {
    [self toggleRemoveButtonEnableState];
    
    [self refreshTableView];
}

- (void)refreshTableView {

    [self.tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView* ret = [self.tableView makeViewWithIdentifier:@"genericEditTagCellIdentifier" owner:nil];

    NSString *item = self.items[row];
    
    ret.textField.stringValue = item;

    return ret;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    slog(@"tableViewSelectionDidChange");
    [self toggleRemoveButtonEnableState];
}

- (void)toggleRemoveButtonEnableState {
    self.buttonRemove.enabled = ( self.tableView.selectedRow != -1 );
}

- (IBAction)onRemove:(id)sender {
    if ( self.tableView.selectedRow != -1) {
        NSString *item = self.items[self.tableView.selectedRow];

        if ( self.onRemove ) {
            self.onRemove(item);
        }

        [self.presentingViewController dismissViewController:self];
    }
}

- (IBAction)onAdd:(id)sender {
    MacAlerts *ma = [[MacAlerts alloc] init];
    NSString* newTag = [ma input:NSLocalizedString(@"mac_vc_please_enter_a_tag", @"Enter a Tag to Add to this Item")
                    defaultValue:@""
                      allowEmpty:NO];
    
    if ( newTag ) {
        if ( self.onAdd ) {
            self.onAdd(newTag);
        }

        [self.presentingViewController dismissViewController:self];
    }
}

@end
