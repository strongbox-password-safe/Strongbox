//
//  NodeDetailsWindowController.m
//  Strongbox
//
//  Created by Mark on 28/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "NodeDetailsWindowController.h"
#import "CustomField.h"
#import "Alerts.h"
#import "NSArray+Extensions.h"
#import "Entry.h"
#import "CustomFieldTableCellView.h"
#import "Settings.h"

@interface NodeDetailsWindowController () < NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate >

@property Node* node;
@property ViewModel* model;
@property BOOL readOnly;
@property ViewController* parentViewController;

@property (weak) IBOutlet NSTableView *tableViewCustomFields;
@property (nonnull, strong, nonatomic) NSArray<CustomField*> *customFields;

@property (weak) IBOutlet NSButton *buttonAddCustomField;
@property (weak) IBOutlet NSButton *buttonRemoveCustomField;

@end

@implementation NodeDetailsWindowController

+ (instancetype)showNode:(Node*)node model:(ViewModel*)model readOnly:(BOOL)readOnly parentViewController:(ViewController*)parentViewController {
    NodeDetailsWindowController *window = [[NodeDetailsWindowController alloc] initWithWindowNibName:@"NodeDetailsWindowController"];
    
    window.node = node;
    window.model = model;
    window.readOnly = readOnly;
    window.parentViewController = parentViewController;
    
    [window showWindow:nil];
    
    return window;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return self.model.document.undoManager;
}

- (void)windowWillClose:(NSNotification *)notification {
    [self stopObservingModelChanges];
    [self.parentViewController onDetailsWindowClosed:self]; // Allows parent VC to remove reference to this
}

- (void)observeModelChanges {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onCustomFieldsChanged:) name:kModelUpdateNotificationCustomFieldsChanged object:nil];
}

- (void)stopObservingModelChanges {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)canEdit {
    return !self.readOnly;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.title = self.readOnly ? [NSString stringWithFormat:@"%@ [Read-Only]", self.node.title] : self.node.title;
    
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    
    [self.window setLevel:Settings.sharedInstance.doNotFloatDetailsWindowOnTop ? NSNormalWindowLevel : NSFloatingWindowLevel];
    
    [self setupCustomFieldsUI];
    
    [self enableDisableFieldsForEditing];
    
    [self refreshCustomFields];
    
    [self observeModelChanges];
}

- (void)enableDisableFieldsForEditing {
    [self enableDisableCustomFieldsForEditing];
}

- (void)enableDisableCustomFieldsForEditing {
    self.buttonAddCustomField.enabled = [self canEdit];
    self.buttonRemoveCustomField.enabled = [self canEdit];
}

- (void)setupCustomFieldsUI {
    self.customFields = [NSArray array];

    self.tableViewCustomFields.dataSource = self;
    self.tableViewCustomFields.delegate = self;
    [self.tableViewCustomFields registerNib:[[NSNib alloc] initWithNibNamed:@"CustomFieldTableCellView" bundle:nil] forIdentifier:@"CustomFieldValueCellIdentifier"];
    self.tableViewCustomFields.doubleAction = @selector(onEditField:);
}

- (void)refreshCustomFields {
    NSArray<NSString*> *sortedKeys = [self.node.fields.customFields.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableArray *fields = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        StringValue* value = self.node.fields.customFields[key];
        
        CustomField* field = [[CustomField alloc] init];
        
        field.key = key;
        field.value = value.value;
        field.protected = value.protected;
        
        [fields addObject:field];
    }
    
    self.customFields = [fields copy];
    [self.tableViewCustomFields reloadData];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    BOOL isKeyColumn = [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"];
    NSString* cellId = isKeyColumn ? @"CustomFieldKeyCellIdentifier" : @"CustomFieldValueCellIdentifier";

    CustomField* field = [self.customFields objectAtIndex:row];

    if(isKeyColumn) {
        NSTableCellView* cell = [self.tableViewCustomFields makeViewWithIdentifier:cellId owner:nil];
        cell.textField.stringValue = field.key;
        return cell;
    }
    else {
        CustomFieldTableCellView* cell = [self.tableViewCustomFields makeViewWithIdentifier:cellId owner:nil];
        
        cell.value = field.value;
        cell.protected = field.protected;
        cell.valueHidden = field.protected; // Initially Hide the Value if it is protected
        
        return cell;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.customFields.count;
}

- (IBAction)onEditField:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }

    CustomField* field = self.customFields[row];
    [self onEditCustomField:field];
}

- (void)onEditCustomField:(CustomField*)field {
    //NSLog(@"onEditCustomField: %@", field);
    
    if([self canEdit]) {
        Alerts* alert = [[Alerts alloc] init];
        
        [alert inputKeyValue:@"Edit Custom Field" initKey:field.key initValue:field.value initProtected:field.protected placeHolder:NO completion:^(BOOL yesNo, NSString *key, NSString *value, BOOL protected) {
            if(yesNo) {
                [self setCustomField:key value:value allowUpdate:YES protected:protected];
            }
        }];
    }
}

- (IBAction)onCopyCustomFieldKey:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:field.key forType:NSStringPboardType];
}

- (IBAction)onCopyCustomFieldValue:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    [NSPasteboard.generalPasteboard clearContents];
    [NSPasteboard.generalPasteboard setString:field.value forType:NSStringPboardType];
}

- (IBAction)onDeleteCustomField:(id)sender {
    NSInteger row = self.tableViewCustomFields.clickedRow;
    if(row == -1) {
        return;
    }
    
    CustomField *field = self.customFields[row];
    
    [Alerts yesNo:[NSString stringWithFormat:@"Are you sure you want to remove the custom field '%@'?", field.key]
           window:self.window
       completion:^(BOOL yesNo) {
           if(yesNo) {
               [self.model removeCustomField:self.node key:field.key];
           }
       }];
}

- (IBAction)onRemoveCustomField:(id)sender {
    if(self.tableViewCustomFields.selectedRow != -1) {
        CustomField *field = self.customFields[self.tableViewCustomFields.selectedRow];
        
        [Alerts yesNo:[NSString stringWithFormat:@"Are you sure you want to remove the custom field '%@'?", field.key]
               window:self.window
           completion:^(BOOL yesNo) {
            if(yesNo) {
                [self.model removeCustomField:self.node key:field.key];
            }
        }];
    }
}

- (IBAction)onAddCustomField:(id)sender {
    Alerts* alert = [[Alerts alloc] init];
    
    [alert inputKeyValue:@"Add Custom Field" initKey:@"Key" initValue:@"Value" initProtected:NO placeHolder:YES completion:^(BOOL yesNo, NSString *key, NSString *value, BOOL protected) {
        if(yesNo) {
            [self setCustomField:key value:value allowUpdate:NO protected:protected];
        }
    }];
}

- (void)setCustomField:(NSString*)key value:(NSString*)value allowUpdate:(BOOL)allowUpdate protected:(BOOL)protected {
    NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
    
    if(!allowUpdate && [existingKeySet containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it already exists in custom fields." window:self.window];
        return;
    }
    
    if([keePassReserved containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it is reserved for standard KeePass fields." window:self.window];
        return;
    }
    
    [self.model setCustomField:self.node key:key value:[StringValue valueWithString:value protected:protected]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    SEL theAction = [menuItem action];
    
    if (theAction == @selector(onDeleteCustomField:)) {
        return [self canEdit];
    }
    
    if (theAction == @selector(onEditField:)) {
        return [self canEdit];
    }
    
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Model Changes...

- (void)onCustomFieldsChanged:(NSNotification*)notification {
    if(notification.object != self.model) {
        return;
    }

    [self refreshCustomFields];
}

@end
