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

@interface CustomFieldsViewController ()

@property NSMutableArray<CustomField*> *workingItems;
@property BOOL dirty;
@property UIAlertController *alertController;
@property UIAlertAction *defaultAction;

@end

@implementation CustomFieldsViewController

- (void)viewDidLoad {
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;

    self.tableView.tableFooterView = [UIView new];
    
    self.tableView.rowHeight = 55.0f;
    
    self.workingItems = self.items ? [self.items mutableCopy] : [NSMutableArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:NO];
    
    [self refresh];
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

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = @"No Custom Fields";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
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
    UITableViewRowAction *removeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Remove" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self removeItem:indexPath];
    }];
    
    UITableViewRowAction *editAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Edit" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        [self editItem:indexPath];
    }];
    
    return @[removeAction, editAction];
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

    [Alerts OkCancelWithTextField:self textFieldText:item.value title:@"Edit Value" message:@"Enter a new value for this item" completion:^(NSString *text, BOOL response) {
        if(response) {
            item.value = text;
            self.dirty = YES;
            [self refresh];
        }}];
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
    return self.workingItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CustomFieldsReuseIdentifier" forIndexPath:indexPath];
    
    CustomField* attachment = [self.workingItems objectAtIndex:indexPath.row];

    cell.textLabel.text = attachment.key;
    cell.detailTextLabel.text = attachment.value;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CustomField* field = [self.workingItems objectAtIndex:indexPath.row];
    
    if (field.value.length == 0) {
        return;
    }
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = field.value;
    
    [ISMessages showCardAlertWithTitle:@"Value Copied to Clipboard"
                               message:nil
                              duration:3.f
                           hideOnSwipe:YES
                             hideOnTap:YES
                             alertType:ISAlertTypeSuccess
                         alertPosition:ISAlertPositionTop
                               didHide:nil];
}

@end
