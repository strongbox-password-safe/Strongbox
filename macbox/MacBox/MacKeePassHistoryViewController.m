//
//  MacKeePassHistoryViewController.m
//  Strongbox
//
//  Created by Mark on 27/12/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "MacKeePassHistoryViewController.h"
#import "NodeIconHelper.h"
#import "MacAlerts.h"
#import "NodeDetailsViewController.h"

@interface MacKeePassHistoryViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *tableViewHistory;
@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSButton *showPasswordsCheckbox;
@property (weak) IBOutlet NSButton *buttonDelete;
@property (weak) IBOutlet NSButton *buttonRestore;

@end

@implementation MacKeePassHistoryViewController

+ (instancetype)instantiateFromStoryboard {
    NSStoryboard* sb = [NSStoryboard storyboardWithName:@"MacKeePassHistory" bundle:nil];
    
    return [sb instantiateInitialController];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    

    if(self.history == nil) {
        self.history = @[];
    }
 
    self.showPasswordsCheckbox.state = NSControlStateValueOff;
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
        NSWindowController *wc = segue.destinationController;
        NodeDetailsViewController* vc = (NodeDetailsViewController*)(wc.contentViewController);
        
        vc.node = sender;
        vc.model = self.model;
        vc.newEntry = NO;
        vc.historicalItem = YES;
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

        cell.imageView.image = [NodeIconHelper getIconForNode:item predefinedIconSet:kKeePassIconSetClassic format:self.model.format];
        cell.textField.stringValue = item.title;
    }
    else if([tableColumn.identifier isEqualToString:@"Username"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = item.fields.username;
    }
    else if([tableColumn.identifier isEqualToString:@"Password"]) {
        cell = [self.tableViewHistory makeViewWithIdentifier:@"HistoryPlainCellIdentifier" owner:nil];
        cell.textField.stringValue = self.showPasswordsCheckbox.state == NSControlStateValueOn ? item.fields.password : @"*************" ;
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











- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self enableDisableButtons];
}

- (void)enableDisableButtons {
    self.buttonDelete.enabled = !self.model.isEffectivelyReadOnly && self.tableViewHistory.selectedRowIndexes.count > 0;
    self.buttonRestore.enabled = !self.model.isEffectivelyReadOnly && self.tableViewHistory.selectedRowIndexes.count > 0;
}

- (IBAction)onDelete:(id)sender {
    NSInteger row = self.tableViewHistory.selectedRow;
    
    if(row == -1) {
        return;
    }
    
    Node* node = self.history[row];
    
    NSString* loc = NSLocalizedString(@"mac_keepass_history_are_sure_delete", @"Are you sure you want to delete this history item?");
    
    [MacAlerts yesNo:loc
           window:self.view.window
       completion:^(BOOL yesNo) {
        if(yesNo) {
            self.onDeleteHistoryItem(node);
            
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
    
    [MacAlerts yesNo:loc
           window:self.view.window
       completion:^(BOOL yesNo) {
        if(yesNo) {
            self.onRestoreHistoryItem(node);
            
            [self.presentingViewController dismissViewController:self];
        }
    }];
}

@end
