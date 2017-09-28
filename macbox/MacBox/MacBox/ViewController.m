//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "Alerts.h"
#import "ChangeMasterPasswordWindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "Utils.h"

#define kDragAndDropUti @"com.markmcguill.strongbox.drag.and.drop.internal.uti"

@interface ViewController ()

@property (strong, nonatomic) ChangeMasterPasswordWindowController *changeMasterPassword;
@property (strong, nonatomic) NSImage *folderImage;
@property (strong, nonatomic) NSImage *strongBox256Image;
@property (strong, nonatomic) NSImage *smallYellowFolderImage;
@property (strong, nonatomic) NSImage *smallLockImage;
@property (nonatomic) BOOL showPassword;
@property (nonatomic) NSString* hiddenPasswordTemporaryStore;

@end

@implementation ViewController

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self initializeFullOrTrialOrLiteUI];
    
    [self setInitialFocus];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self loadUIImages];
    
    [self enableDragDrop];

    [self customizeUi];

    [self bindToModel];
}

- (void)customizeUi {
    self.buttonRevealDetail.layer.cornerRadius = 20;
    self.checkboxRevealDetailsImmediately.state = [Settings sharedInstance].revealDetailsImmediately;
    
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
    
    [self.comboboxUsername setDataSource:self];
}

- (void)loadUIImages {
    self.folderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
    self.strongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
    self.smallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
    self.smallLockImage = [NSImage imageNamed:@"lock-48"];
}

- (void)disableFeaturesForLiteVersion {
    [self.searchField setPlaceholderString:@"Search Disabled - Please Upgrade"];
    self.searchField.enabled = NO;
    self.searchSegmentedControl.enabled = NO;
}

- (void)enableFeaturesForFullVersion {
    [self.searchField setPlaceholderString:@"Search (⌘F)"];
    self.searchField.enabled = YES;
    self.searchSegmentedControl.enabled = YES;
}

- (void)initializeFullOrTrialOrLiteUI {
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial) {
        [self disableFeaturesForLiteVersion];
    }
    else {
        [self enableFeaturesForFullVersion];
    }
}

-(void)setModel:(ViewModel *)model {
    _model = model;
    [self bindToModel];
}

-(void)updateDocumentUrl {
    [self bindStatusPane];
    
    [self bindDetailsPane];
}

- (NSString * _Nonnull)bindStatusPane {
    return self.labelLeftStatus.stringValue = self.model.fileUrl ?
        //[[[NSFileManager defaultManager] componentsToDisplayForPath:self.model.fileUrl.path] componentsJoinedByString:@"/"]:
    self.model.fileUrl.path :
    @"[Not Saved]";
}

- (void)bindToModel {
    if(self.model == nil) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:2];
        [self.outlineView reloadData];
        return;
    }
    
    if(self.model.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
    }
    else {        
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
    }
    
    [self.outlineView reloadData];
    
    [self bindDetailsPane];
    
    [self bindStatusPane];
}

- (void)setInitialFocus {
    if(self.model == nil || self.model.locked) {
        [self.view.window makeFirstResponder:self.textFieldMasterPassword];
    }
    else {
        [self.view.window makeFirstResponder:self.outlineView];
    }
}

- (void)bindDetailsPane {
    Node* it = [self getCurrentSelectedItem];
    
    if(!it) {        
        [self.tabViewRightPane selectTabViewItemAtIndex:2];
        [self updateSafeSummaryFields];
    }
    else if (it.isGroup) {
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        self.textFieldSummaryTitle.stringValue = it.title;
    }
    else {
        self.textFieldTitle.stringValue = it.title;
        self.textFieldPw.stringValue = it.fields.password;
        self.textFieldUrl.stringValue = it.fields.url;
        self.comboboxUsername.stringValue = it.fields.username;
        self.textViewNotes.string = it.fields.notes;
        self.textFieldSummaryTitle.stringValue = it.title;

        if([Settings sharedInstance].revealDetailsImmediately) {
            [self revealDetails];
        }
        else {
            [self concealDetails];
        }
        
        [self showOrHidePassword];
    }
}

- (IBAction)onRevealDetails:(id)sender {
    [self revealDetails];
}

- (IBAction)onConcealDetails:(id)sender {
    [self concealDetails];
}

- (void)revealDetails {
    [self.tabViewRightPane selectTabViewItemAtIndex:0];
}

- (void)concealDetails {
    [self.tabViewRightPane selectTabViewItemAtIndex:3];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if(!self.model || self.model.locked) {
        return NO;
    }
    
    if(item == nil) {
        NSArray<Node*> *items = [self getSafeItems:self.model.rootGroup];
        
        return items.count > 0;
    }
    else {
        Node *it = (Node*)item;
        
        if(it.isGroup) {
            NSArray<Node*> *items = [self getSafeItems:it];
            
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
    
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    
    NSArray<Node*> *items = [self getSafeItems:group];
    
    return items.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    Node* group = (item == nil) ? self.model.rootGroup : ((Node*)item);
    
    NSArray<Node*> *items = [self getSafeItems:group];
    
    return items[index];
}

- (NSArray<Node*> *)getSafeItems:(Node*)parentGroup {
    if(!self.model || self.model.locked) {
        NSLog(@"Request for safe items while model nil or locked!");
        return @[];
    }
    
    return [parentGroup.children filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [self isSafeItemMatchesSearchCriteria:evaluatedObject recurse:YES];
    }]];
}

- (BOOL)isSafeItemMatchesSearchCriteria:(Node*)item recurse:(BOOL)recurse {
    NSString* searchText = self.searchField.stringValue;
    
    if(![searchText length]) {
        return YES;
    }
    
    NSPredicate *predicate;
    
    NSInteger scope = self.searchSegmentedControl.selectedSegment;
    if (scope == 0) {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@", searchText];
    }
    else if (scope == 1)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.username contains[c] %@", searchText];
    }
    else if (scope == 2)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.password contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ OR fields.password contains[c] %@  "
                     @"OR fields.username contains[c] %@  "
                     @"OR fields.url contains[c] %@  "
                     @"OR fields.notes contains[c] %@", searchText, searchText, searchText, searchText, searchText];
    }

    if([predicate evaluateWithObject:item]) {
        return YES;
    }
    else if(item.isGroup && recurse) {
        for(Node* child in item.children) {
            if(child.isGroup) {
                if([[self getSafeItems:child] count] > 0) {
                    return YES;
                }
            }
            else {
                if([self isSafeItemMatchesSearchCriteria:child recurse:YES]) {
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item
{
    return item;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(nonnull id)item {
    NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"CellIdentifier" owner:self];

    Node *it = (Node*)item;
    
    cell.textField.stringValue = it.title;
    cell.imageView.objectValue = it.isGroup ? self.smallYellowFolderImage : self.smallLockImage;
    
    return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    NSLog(@"Selection Change Outline View");
    Node* item =  [self getCurrentSelectedItem];
    
    self.hiddenPasswordTemporaryStore = item == nil || item.isGroup ? nil : item.fields.password;
    
    [self bindDetailsPane];
}

- (IBAction)onEnterMasterPassword:(id)sender {
    [self unlock];
}

- (IBAction)onUnlock:(id)sender {
    [self unlock];
}

- (void)unlock {
    if(self.model && self.model.locked) {
        NSError *error;
        NSString *selectedItemId;
        
        if([self.model unlock:self.textFieldMasterPassword.stringValue selectedItem:&selectedItemId error:&error]) {
            [self bindToModel];
            
            self.textFieldMasterPassword.stringValue = @"";
            
            Node* selectedItem = [self.model getItemFromSerializationId:selectedItemId];
            
            [self selectItem:selectedItem];
            
            [self setInitialFocus];
        }
        else {
            [Alerts error:@"Could not open safe" error:error window:self.view.window];
        }
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        if(self.model.dirty) {
            [Alerts info:@"You cannot lock a safe while changes are pending. Save your changes first." window:self.view.window];
            //            NSLog(@"Saving...");
            //            
            //            SEL selector = NSSelectorFromString(@"saveDocument:");
            //            [[NSApplication sharedApplication] sendAction:selector to:nil from:self];
            //            
            //[NSApplication sharedApplication] sendAction:NSSelectorFromString(saveDocument: to:]; from:(nullable id)
        }
        else {
            NSError* error;
            
            Node* item = [self getCurrentSelectedItem];
            
            if(![self.model lock:&error selectedItem:item.serializationId]) {
                [Alerts error:error window:self.view.window];
                return;
            }
            
            [self bindToModel];
            
            self.textFieldMasterPassword.stringValue = @"";
            [self setInitialFocus];
        }
    }
}

- (IBAction)onOutlineViewDoubleClick:(id)sender {
    Node *item = [sender itemAtRow:[sender clickedRow]];
    
    if ([sender isItemExpanded:item]) {
        [sender collapseItem:item];
    }
    else {
        [sender expandItem:item];
    }
}

- (IBAction)onFind:(id)sender {
    [self.view.window makeFirstResponder:self.searchField];
}

- (IBAction)onChangeMasterPassword:(id)sender {
    if(self.model && !self.model.locked) {
        self.changeMasterPassword = [[ChangeMasterPasswordWindowController alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
        
        self.changeMasterPassword.titleText = @"Change Master Password";
        
        [self.view.window beginSheet:self.changeMasterPassword.window  completionHandler:^(NSModalResponse returnCode) {
            if(returnCode == NSModalResponseOK) {
                [self.model setMasterPassword:self.changeMasterPassword.confirmedPassword];
                [Alerts info:@"Master Password Changed" window:self.view.window];
            }
        }];
    }
}

- (IBAction)onSearch:(id)sender {
    //NSLog(@"Search For: %@", self.searchField.stringValue);
    
    [self.outlineView reloadData];
    
    if( self.searchField.stringValue.length > 0) {
        self.buttonCreateGroup.enabled = NO;
        self.buttonCreateRecord.enabled = NO;
        [self.outlineView expandItem:nil expandChildren:YES];
    }
    else {
        self.buttonCreateGroup.enabled = YES;
        self.buttonCreateRecord.enabled = YES;
        [self.outlineView collapseItem:nil collapseChildren:YES];
    }
    
    for(int i=0;i < [self.outlineView numberOfRows];i++) {
        //NSLog(@"Searching: %d", i);
        Node* node = [self.outlineView itemAtRow:i];
        
        if([self isSafeItemMatchesSearchCriteria:node recurse:NO]) {
            //NSLog(@"Found: %@", node.title);
            [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
            break;
        }
    }
    
    [self bindDetailsPane];
}

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender {
    [Settings sharedInstance].revealDetailsImmediately = self.checkboxRevealDetailsImmediately.state;
}

- (IBAction)onToggleShowHidePassword:(id)sender {
    self.showPassword = !self.showPassword;
    
    [self showOrHidePassword];
}

- (void)showOrHidePassword {
    if(self.showPassword) {
        self.textFieldPw.enabled = YES;
        self.textFieldPw.stringValue = self.hiddenPasswordTemporaryStore;
        self.buttonShowHidePassword.title = @"Hide Password (⌘P)";
    }
    else {
        self.hiddenPasswordTemporaryStore = self.textFieldPw.stringValue;
        self.textFieldPw.enabled = NO;
        self.textFieldPw.stringValue = @"***********************";
        self.buttonShowHidePassword.title = @"Show Password (⌘P)";
    }
}

- (IBAction)onCopyTitle:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldTitle.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUsername:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.comboboxUsername.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textFieldUrl.stringValue forType:NSStringPboardType];
}

- (IBAction)onCopyNotes:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.textViewNotes.textStorage.string forType:NSStringPboardType];
}

- (IBAction)onCopyPassword:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];
}

- (Node*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    //NSLog(@"Selected Row: %ld", (long)selectedRow);
    
    return [self.outlineView itemAtRow:selectedRow];
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return [self getUsernameAutocompletes].count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return [[self getUsernameAutocompletes] objectAtIndex:index];
}

- (NSArray<NSString*>*)getUsernameAutocompletes {
    return [[self.model.usernameSet allObjects] sortedArrayUsingComparator:finderStringComparator];
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification{
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    //NSLog(@"comboBoxSelectionDidChange");

    if(notification.object == self.comboboxUsername) {
        NSString *strValue = [[self getUsernameAutocompletes] objectAtIndex:[notification.object indexOfSelectedItem]];
        strValue = [Utils trim:strValue];
        
        Node* item = [self getCurrentSelectedItem];

        if(![item.fields.username isEqualToString:strValue]) {
            [self.model setItemUsername:item username:strValue];
            item.fields.accessed = [[NSDate alloc] init];
            item.fields.modified = [[NSDate alloc] init];
        }
    }
}

- (void)textDidChange:(NSNotification *)notification {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    Node* item = [self getCurrentSelectedItem];
    if(notification.object == self.textViewNotes &&
       ![item.fields.notes isEqualToString:self.textViewNotes.textStorage.string]) {
        [self.model setItemNotes:item notes:self.textViewNotes.textStorage.string];
        item.fields.accessed = [[NSDate alloc] init];
        item.fields.modified = [[NSDate alloc] init];
    }
}

- (IBAction)controlTextDidChange:(NSNotification *)obj
{
    //NSLog(@"controlTextDidChange");
    [self onDetailFieldChange:obj.object];
}

- (IBAction)onDetailFieldChange:(id)sender {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    Node* item = [self getCurrentSelectedItem];
    BOOL recordChanged = NO;
    
    if(sender == self.textFieldTitle) {
        if(![item.title isEqualToString:trimField(self.textFieldTitle)]) {
            [self.model setItemTitle:item title:trimField(self.textFieldTitle)];
            
            NSInteger row = [self.outlineView selectedRow];
            [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
        
            recordChanged = YES;
        }
    }
    else if(sender == self.comboboxUsername) {
        if(![item.fields.username isEqualToString:trimField(self.comboboxUsername)]) {
            [self.model setItemUsername:item username:trimField(self.comboboxUsername)];

            recordChanged = YES;
        }
    }
    else if(sender == self.textFieldUrl) {
        if(![item.fields.url isEqualToString:trimField(self.textFieldUrl)]) {
            [self.model setItemUrl:item url:trimField(self.textFieldUrl)];
        
            recordChanged = YES;
        }
    }
    else if(sender == self.textFieldPw) {
        if(![item.fields.password isEqualToString:trimField(self.textFieldPw)]) {
            [self.model setItemPassword:item password:trimField(self.textFieldPw)];
        
            recordChanged = YES;
        }
    }
    
    if(recordChanged) {
        item.fields.accessed = [[NSDate alloc] init];
        item.fields.modified = [[NSDate alloc] init];
    }
}

- (IBAction)onOutlineViewItemEdited:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(item == nil) {
        return;
    }
    
    NSTextField *textField = (NSTextField*)sender;

    NSString* newTitle = trimField(textField);
    if(![item.title isEqualToString:newTitle]) {
        //SafeItemViewModel *newlyNamedItem =
        
        if(![self.model setItemTitle:item title:newTitle]) {
            [Alerts info:@"You cannot change the title of this item to this value." window:self.view.window];
        }

        [self reloadDataAndSelectItem:item];
         
        [self bindDetailsPane];
    }
    else {
        textField.stringValue = newTitle;
    }
}

NSString* trimField(NSTextField* textField) {
    return [Utils trim:textField.stringValue];
}

- (void)expandParentsOfItem:(Node*)item {
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    
    while (item.parent != nil) {
        item = item.parent;
        
        //NSLog(@"Got Parent == %@", i.title);
        
        [stack addObject:item];
    }
    
    while ([stack count]) {
        Node *group = [stack lastObject];
        
        //NSLog(@"Expanding %@", group.title);
        [self.outlineView expandItem:group];
        
        [stack removeObject:group];
    }
}

- (NSInteger)findRowForItemExpandIfNecessary:(id)item {
    NSInteger itemIndex = [self.outlineView rowForItem:item];
    
    if (itemIndex < 0) {
        [self expandParentsOfItem: item];
        
        itemIndex = [self.outlineView rowForItem:item];
        
        if (itemIndex < 0) {
            return itemIndex;
        }
    }
    
    return itemIndex;
}

- (void)reloadDataAndSelectItem:(Node*)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.outlineView reloadData];
        
        [self selectItem:item];
    });
}
                   
- (void)selectItem:(Node*)item {
    if(item) {
        NSInteger row = [self findRowForItemExpandIfNecessary:item];
        
        if(row >= 0) {
            [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        }
        else {
            NSLog(@"Could not find item row for selection to maintain");
        }
    }
}

- (void)enableDragDrop {
    [self.outlineView registerForDraggedTypes:[NSArray arrayWithObject:kDragAndDropUti]];
}

- (id<NSPasteboardWriting>)outlineView:(NSOutlineView *)outlineView pasteboardWriterForItem:(id)item {
    NSPasteboardItem *paste = [[NSPasteboardItem alloc] init];
    
    Node* it = ((Node*)item);
    
    NSLog(@"pasteboardWriterForItem %@ => [%@]", it.title, it.serializationId);
    
    [paste setString:it.serializationId forType:kDragAndDropUti];

    return paste;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index
{
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];

    Node* sourceItem = [self.model getItemFromSerializationId:itemId];
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;
    
    //NSLog(@"validate Move [%@] [%@] -> [%@]", itemId, sourceItem, destinationItem);
    
    BOOL valid = !destinationItem ||
                (destinationItem.isGroup && [self.model validateChangeParent:destinationItem node:sourceItem]);

    return valid ? NSDragOperationMove : NSDragOperationNone;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id<NSDraggingInfo>)info
              item:(id)item
        childIndex:(NSInteger)index {
    NSString* itemId = [info.draggingPasteboard stringForType:kDragAndDropUti];
    Node* sourceItem = [self.model getItemFromSerializationId:itemId];
    Node* destinationItem = (item == nil) ? self.model.rootGroup : item;
    
    NSLog(@"acceptDrop Move [%@] -> [%@]", sourceItem, destinationItem);
    
    if([self.model changeParent:destinationItem node:sourceItem]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.outlineView reloadData];
        });
        
        return YES;
    }
    
    return NO;
}

- (IBAction)onCreateRecord:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    Node *newItem = [self.model addNewRecord:parent];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
        if ([cellView.textField acceptsFirstResponder]) {
            [cellView.window makeFirstResponder:cellView.textField];
        }
    }
}

- (IBAction)onCreateGroup:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    Node *newItem = [self.model addNewGroup:parent];
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
        if ([cellView.textField acceptsFirstResponder]) {
            [cellView.window makeFirstResponder:cellView.textField];
        }
    }
}

- (IBAction)onDelete:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    
    if(!item) {
        return;
    }
    
    [Alerts yesNo:@"Are you sure you want to delete this item?" window:self.view.window completion:^(BOOL yesNo) {
        if(yesNo) {
            [self.model deleteItem:item];
            
            [self.outlineView reloadData];
            
            [self bindDetailsPane];
        }
    }];
}

- (IBAction)onLaunchUrl:(id)sender {
    NSString *urlString = self.textFieldUrl.stringValue;
    
    if (!urlString.length) {
        return;
    }
    
    if (![urlString.lowercaseString hasPrefix:@"http://"] &&
        ![urlString.lowercaseString hasPrefix:@"https://"]) {
        urlString = [NSString stringWithFormat:@"http://%@", urlString];
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)onCopyPasswordAndLaunchUrl:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];

    [self onLaunchUrl:sender];
}

- (IBAction)onCopyDiagnosticDump:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *dump = [self.model getDiagnosticDumpString];
    
    [[NSPasteboard generalPasteboard] setString:dump forType:NSStringPboardType];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];
    
    Node* item = [self getCurrentSelectedItem];
    
    if (theAction == @selector(onDelete:)) {
        return item != nil;
    }
    else if(theAction == @selector(onCreateGroup:) ||
            theAction == @selector(onCreateRecord:)) {
        return self.model && !self.model.locked && self.searchField.stringValue.length == 0;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onLock:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onFind:)) {
        return self.model && !self.model.locked &&
        ([Settings sharedInstance].fullVersion || [Settings sharedInstance].freeTrial);
    }
    else if(theAction == @selector(onLaunchUrl:) ||
            theAction == @selector(onCopyUrl:)) {
        return item && !item.isGroup && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyTitle:)) {
        return item && !item.isGroup && self.textFieldTitle.stringValue.length;
    }
    else if (theAction == @selector(onCopyUsername:)) {
        return item && !item.isGroup && self.comboboxUsername.stringValue.length;
    }
    else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
        NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
        
        return item && !item.isGroup && password.length && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyPassword:)) {
        NSString *password = self.showPassword ? self.textFieldPw.stringValue : self.hiddenPasswordTemporaryStore;
        return item && !item.isGroup && password.length;
    }
    else if (theAction == @selector(onCopyNotes:)) {
        return item && !item.isGroup && self.textViewNotes.textStorage.string.length;
    }
    
    return YES;
}

- (IBAction)onGenerate:(id)sender {
    self.showPassword = YES;
    [self showOrHidePassword];

    self.textFieldPw.stringValue = [self.model generatePassword];
    
    [self onDetailFieldChange:self.textFieldPw];
}

- (void)updateSafeSummaryFields {
    self.textFieldSafeSummaryPath.stringValue = self.model.fileUrl ? self.model.fileUrl.path : @"<Not Saved>";
    self.testFieldSafeSummaryUniqueUsernames.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.usernameSet.count];
    self.textFieldSafeSummaryUniquePasswords.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.passwordSet.count];
    self.textFieldSafeSummaryMostPopularUsername.stringValue = self.model.mostPopularUsername ? self.model.mostPopularUsername : @"<None>";
    self.textFieldSafeSummaryRecords.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.numberOfRecords];
    self.textFieldSafeSummaryGroups.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.numberOfGroups];
    self.textFieldSafeSummaryKeyStretchIterations.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)self.model.keyStretchIterations];
    self.textFieldSafeSummaryVersion.stringValue = self.model.version ? self.model.version : @"<Unknown>";
    
    self.textFieldSafeSummaryLastUpdateUser.stringValue = self.model.lastUpdateUser ? self.model.lastUpdateUser : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateHost.stringValue = self.model.lastUpdateHost ? self.model.lastUpdateHost : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateApp.stringValue = self.model.lastUpdateApp ? self.model.lastUpdateApp : @"<Unknown>";
    self.textFieldSafeSummaryLastUpdateTime.stringValue = [self formatDate:self.model.lastUpdateTime];
}

- (NSString *)formatDate:(NSDate *)date {
    if (!date) {
        return @"<Unknown>";
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    dateFormatter.locale = [NSLocale currentLocale];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    return dateString;
}


static NSComparator finderStringComparator = ^(id obj1, id obj2)
{
    return [Utils finderStringCompare:obj1 string2:obj2];
};

@end
