//
//  MacKeePassHistoryViewController.m
//  Strongbox
//
//  Created by Mark on 27/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MacKeePassHistoryViewController.h"
#import "MacNodeIconHelper.h"
#import "Alerts.h"
#import "NodeDetailsViewController.h"

@interface MacKeePassHistoryViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *tableViewHistory;
@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSButton *showPasswordsCheckbox;
@property (weak) IBOutlet NSButton *buttonDelete;
@property (weak) IBOutlet NSButton *buttonRestore;

@end

@implementation MacKeePassHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

    if(self.history == nil) {
        self.history = @[];
    }
 
    self.showPasswordsCheckbox.state = NSOffState;
    self.tableViewHistory.dataSource = self;
    self.tableViewHistory.delegate = self;
    self.tableViewHistory.doubleAction = @selector(onDoubleClick:);
    
    [self enableDisableButtons];
}

- (IBAction)onDoubleClick:(id)sender {
    NSInteger row = self.tableViewHistory.clickedRow;
    if(row == -1) {
        return;
    }
    
    Node* node = self.history[row];
    [self openDetails:node];
}

- (void)openDetails:(Node*)node {
    [self performSegueWithIdentifier:@"segueToItemDetails" sender:node];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToItemDetails"]) {
        NodeDetailsViewController* vc = (NodeDetailsViewController*)segue.destinationController;

        vc.node = sender;
        vc.model = self.model;
        vc.newEntry = NO;
        vc.historical = YES;
        vc.onClosed = nil;
    }
}

- (IBAction)onShowPasswords:(id)sender {
    [self.tableViewHistory reloadData];
}

- (IBAction)onClose:(id)sender {
    [self.presentingViewController dismissViewController:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.history.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Node* item = self.history[row];
    
    NSTableCellView* cell;
    if([tableColumn.identifier isEqualToString:@"TitleColumnIdentifier"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryTitleCellIdentifier" owner:nil];

        cell.imageView.image = [MacNodeIconHelper getIconForNode:self.model vm:item large:NO];
        cell.textField.stringValue = item.title;
    }
    else if([tableColumn.identifier isEqualToString:@"Username"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = item.fields.username;
    }
    else if([tableColumn.identifier isEqualToString:@"Password"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = self.showPasswordsCheckbox.state == NSOnState ? item.fields.password : @"*************" ;
    }
    else if([tableColumn.identifier isEqualToString:@"URL"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = item.fields.url;
    }
    else if([tableColumn.identifier isEqualToString:@"Notes"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = [item.fields.notes componentsSeparatedByString:@"\n"][0];
    }
    else if([tableColumn.identifier isEqualToString:@"CustomFields"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = [NSString stringWithFormat:@"%@",  item.fields.customFields.count == 0 ? @"❌" : @"✅"];
    }
    else if([tableColumn.identifier isEqualToString:@"Attachments"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = [NSString stringWithFormat:@"%@",  item.fields.attachments.count == 0 ? @"❌" : @"✅"];
    }
    else if([tableColumn.identifier isEqualToString:@"LastModified"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = [self formatDate:item.fields.modified];
    }
    else {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = @"Unknown!!";
    }
    
    return cell;
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) {
        return @"<Unknown>";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];
    dateFormatter.doesRelativeDateFormatting = YES;
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}

//- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
//    if(tableView != self.tableViewSummary) {
//        CustomField* field = [self.customFields objectAtIndex:row];
//        return [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"] ? field.key : field.value;
//    }
//    else {
//        return nil;
//    }
//}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self enableDisableButtons];
}

- (void)enableDisableButtons {
    self.buttonDelete.enabled = self.tableViewHistory.selectedRowIndexes.count > 0;
    self.buttonRestore.enabled = self.tableViewHistory.selectedRowIndexes.count > 0;
}

- (IBAction)onDelete:(id)sender {
    NSInteger row = self.tableViewHistory.selectedRow;
    
    if(row == -1) {
        return;
    }
    
    Node* node = self.history[row];
    
    NSString* loc = NSLocalizedString(@"mac_keepass_history_are_sure_delete", @"Are you sure you want to delete this history item?");
    
    [Alerts yesNo:loc
           window:self.view.window
       completion:^(BOOL yesNo) {
        if(yesNo) {
            self.onDeleteHistoryItem(node);
            // [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
            [self.tableViewHistory removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation:NSTableViewAnimationSlideUp];
        }
    }];
}

- (IBAction)onRestore:(id)sender {
    NSInteger row = self.tableViewHistory.selectedRow;
    
    if(row == -1) {
        return;
    }
    
    Node* node = self.history[row];
    
    NSString* loc = NSLocalizedString(@"mac_keepass_history_are_sure_restore", @"Are you sure you want to restore this history item?");
    
    [Alerts yesNo:loc
           window:self.view.window
       completion:^(BOOL yesNo) {
        if(yesNo) {
            self.onRestoreHistoryItem(node);
            
            [self.presentingViewController dismissViewController:self];
        }
    }];
}

@end
