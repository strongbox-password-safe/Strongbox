//
//  CustomFieldsViewController.m
//  Strongbox
//
//  Created by Mark on 26/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CustomFieldsViewController.h"
#import "Alerts.h"
#import "ISMessages/ISMessages.h"
#import "NSArray+Extensions.h"
#import "Entry.h"
#import "CustomFieldTableCell.h"
#import "ClipboardManager.h"
#import "UITableView+EmptyDataSet.h"

@interface CustomFieldsViewController ()

@property NSMutableArray<CustomField*> *workingItems;
@property BOOL dirty;
@property UIAlertController *alertController;
@property UIAlertAction *defaultAction;

@end

@implementation CustomFieldsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 55.0f;
    
    self.workingItems = self.items ? [self.items mutableCopy] : [NSMutableArray array];
    
    self.buttonAdd.enabled = !self.readOnly;
}

- (void)onCellHeightChangedNotification {
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onCellHeightChangedNotification)
                                                 name:CustomFieldCellHeightChanged
                                               object:nil];

    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [NSNotificationCenter.defaultCenter removeObserver:self name:CustomFieldCellHeightChanged object:nil];
}

- (void)refresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
    });
}

- (IBAction)onDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if(self.onDoneWithChanges && self.dirty) {
        self.items = self.workingItems;
        self.onDoneWithChanges();
    }
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSAttributedString *)getTitleForEmptyDataSet {
    NSString *text = @"No Custom Fields";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)getDescriptionForEmptyDataSet {
    NSString *text = @"Tap the + button in the top right corner to add a custom field";
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (nullable NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if(self.readOnly) {
        return @[];
    }

    CustomField* item = [self.workingItems objectAtIndex:indexPath.row];

    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeItem:indexPath];
    }];
    
    UITableViewRowAction *editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Edit" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self editItem:indexPath];
    }];
    editAction.backgroundColor = UIColor.systemBlueColor;
    
    UITableViewRowAction *toggleProtectAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:item.protected ? @"Unprotect" : @"Protect" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        item.protected = !item.protected;
        self.dirty = YES;
        [self refresh];
    }];
    toggleProtectAction.backgroundColor = UIColor.systemOrangeColor;
    
    return @[removeAction, editAction, toggleProtectAction];
}

- (void)removeItem:(NSIndexPath*)indexPath {
    [Alerts yesNo:self title:@"Are you sure?" message:@"Are you sure you want to remove this item?" action:^(BOOL response) {
        if(response) {
            CustomField* item = [self.workingItems objectAtIndex:indexPath.row];
            [self.workingItems removeObject:item];

            self.dirty = YES;
            [self refresh];
        }
    }];
}

- (void)editItem:(NSIndexPath*)indexPath {
    CustomField* item = [self.workingItems objectAtIndex:indexPath.row];

    self.alertController = [UIAlertController alertControllerWithTitle:@"Edit Custom field"
                                                               message:nil
                                                        preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof(self) weakSelf = self;
    
    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        [textField addTarget:weakSelf
                      action:@selector(validateNewCustomField:)
            forControlEvents:UIControlEventEditingChanged];
        
        textField.text = item.key;
    }];
    
    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        [textField addTarget:weakSelf
                      action:@selector(validateEditCustomField:)
            forControlEvents:UIControlEventEditingChanged];
        
        textField.text = item.value;
    }];
    
    self.defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    NSString* key = weakSelf.alertController.textFields[0].text;
                                                    NSString* value = weakSelf.alertController.textFields[1].text;

                                                    if([key compare:item.key] != NSOrderedSame) {
                                                        NSArray<NSString*>* existingKeys = [self.workingItems map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
                                                            return obj.key;
                                                        }];
                                                        
                                                        NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
                                                        
                                                        if([existingKeySet containsObject:key]) {
                                                            [Alerts warn:self title:@"Conflict" message:@"Cannot change key to this value as this key already exists."];
                                                            return;
                                                        }
                                                    }
                                                    
                                                    item.key = key;
                                                    item.value = value;
                                                    self.dirty = YES;
                                                    [self refresh];
                                                }];
    self.defaultAction.enabled = YES;
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [self.alertController addAction:self.defaultAction];
    [self.alertController addAction:cancelAction];
    
    [self presentViewController:self.alertController animated:YES completion:nil];
}

- (IBAction)onAddCustomField:(id)sender {
    self.alertController = [UIAlertController alertControllerWithTitle:@"New Custom Field"
                                                               message:@"Enter a Key and a Value for your new custom field"
                                                        preferredStyle:UIAlertControllerStyleAlert];

    __weak typeof(self) weakSelf = self;
    
    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        [textField addTarget:weakSelf
                      action:@selector(validateNewCustomField:)
            forControlEvents:UIControlEventEditingChanged];
        
        textField.placeholder = @"Key";
    }];

    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        [textField addTarget:weakSelf
                      action:@selector(validateNewCustomField:)
            forControlEvents:UIControlEventEditingChanged];
        
        textField.placeholder = @"Value";
    }];
    
    self.defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    NSString* key = weakSelf.alertController.textFields[0].text;
                                                    NSString* value = weakSelf.alertController.textFields[1].text;
                                                    [self addNewField:key value:value];
                                                }];
    self.defaultAction.enabled = NO;
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [self.alertController addAction:self.defaultAction];
    [self.alertController addAction:cancelAction];
    
    [self presentViewController:self.alertController animated:YES completion:nil];
}

- (void)validateEditCustomField:(UITextField *)sender {
    UITextField *keyField = _alertController.textFields[0];
    NSString* key = keyField.text;

    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
    
    (self.defaultAction).enabled = ![keePassReserved containsObject:key] && key.length;
}

- (void)validateNewCustomField:(UITextField *)sender {
    UITextField *keyField = _alertController.textFields[0];
    NSString* key = keyField.text;
    
    NSArray<NSString*>* existingKeys = [self.workingItems map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];

    (self.defaultAction).enabled = ![existingKeySet containsObject:key] && ![keePassReserved containsObject:key] && key.length;
}

- (void)addNewField:(NSString*)key value:(NSString*)value {
    CustomField* field = [[CustomField alloc] init];
    
    field.key = key;
    field.value = value;
    
    [self.workingItems addObject:field];
    
    self.dirty = YES;
    
    [self refresh];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.workingItems.count == 0) {
        [self.tableView setEmptyTitle:[self getTitleForEmptyDataSet] description:[self getDescriptionForEmptyDataSet]];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }
    
    return self.workingItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomField* field = [self.workingItems objectAtIndex:indexPath.row];

    CustomFieldTableCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CustomFieldsReuseIdentifier" forIndexPath:indexPath];

    cell.key = field.key;
    cell.value = field.value;
    cell.hidden = field.protected;
    cell.isHideable = field.protected;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomField* field = [self.workingItems objectAtIndex:indexPath.row];
    
    if (field.value.length == 0) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:field.value];
    
    [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"'%@' Value Copied to Clipboard", field.key]
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
