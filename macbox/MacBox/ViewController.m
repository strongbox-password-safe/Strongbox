//
//  ViewController.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "ViewController.h"
#import "Alerts.h"
#import "CreateFormatAndSetCredentialsWizard.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "CHCSVParser.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "SafesList.h"
#import "BiometricIdHelper.h"
#import "PreferencesWindowController.h"
#import "Csv.h"
#import "AttachmentItem.h"
#import "CustomField.h"
#import "Entry.h"
#import "KeyFileParser.h"
#import "ProgressWindow.h"

#define kDragAndDropUti @"com.markmcguill.strongbox.drag.and.drop.internal.uti"

@interface ViewController ()

@property (strong, nonatomic) CreateFormatAndSetCredentialsWizard *changeMasterPassword;
@property (strong, nonatomic) ProgressWindow* progressWindow;
@property (nonatomic) BOOL showPassword;
@property (strong, nonatomic) NSArray<NSString*>* emailAutoCompleteCache;
@property (strong, nonatomic) NSArray<NSString*>* usernameAutoCompleteCache;
@property (nonnull, strong, nonatomic) NSArray *attachments;
@property NSMutableDictionary<NSNumber*, NSImage*> *attachmentsIconCache;
@property (nonnull, strong, nonatomic) NSArray<CustomField*> *customFields;
@end

static NSImage* kFolderImage;
static NSImage* kStrongBox256Image;
static NSImage* kSmallYellowFolderImage;
static NSImage* kSmallLockImage;
static NSImage* kDefaultAttachmentIcon;

static NSArray<NSImage*> *kKeePassIconSet;

@implementation ViewController

+ (void)initialize {
    if(self == [ViewController class]) {
        kKeePassIconSet = getKeePassIconSet();
        
        kFolderImage = [NSImage imageNamed:@"blue-folder-cropped-256"];
        kStrongBox256Image = [NSImage imageNamed:@"StrongBox-256x256"];
        kSmallYellowFolderImage = [NSImage imageNamed:@"Places-folder-yellow-icon-32"];
        kSmallLockImage = [NSImage imageNamed:@"lock-48"];
        kDefaultAttachmentIcon = [NSImage imageNamed:@"document_empty_64"];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self initializeFullOrTrialOrLiteUI];
    
    [self setInitialFocus];
}

- (void)updateAutocompleteCaches {
    // NB: We use these caches tso that we don't get a feedback when entering entries in the fields and setting them on the model. Also PERF
    
    self.emailAutoCompleteCache = self.model ? [[self.model.emailSet allObjects] sortedArrayUsingComparator:finderStringComparator] : [NSArray array];
    self.usernameAutoCompleteCache = self.model ? [[self.model.usernameSet allObjects] sortedArrayUsingComparator:finderStringComparator] : [NSArray array];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self enableDragDrop];

    [self customizeUi];

    [self bindToModel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAutoLock:) name:kAutoLockTime object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPreferencesChanged:) name:kPreferencesChangedNotification object:nil];
}

- (void)customizeUi {
    self.buttonRevealDetail.layer.cornerRadius = 20;
    self.checkboxRevealDetailsImmediately.state = [Settings sharedInstance].revealDetailsImmediately;
    
    [self.tabViewLockUnlock setTabViewType:NSNoTabsNoBorder];
    [self.tabViewRightPane setTabViewType:NSNoTabsNoBorder];
    
    [self.comboboxUsername setDataSource:self];
    [self.comboBoxEmail setDataSource:self];
    
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:@"Unlock with %@", BiometricIdHelper.sharedInstance.biometricIdName];
    
    // Password
    
    if (@available(macOS 10.13, *)) {
        self.textFieldPw.textColor = [NSColor colorNamed:@"password-field-text-color"];

    } else {
        self.textFieldPw.textColor = [NSColor controlTextColor];
    }

    NSFont *ft = [NSFont fontWithName:@"SourceSansPro-Bold" size:16.0];
    NSLog(@"Loaded Font: %@", ft);
    if(ft) {
        self.textFieldPw.font = ft;
        self.textFieldHiddenPassword.font = ft;
    }
    
    // Any Clicks into the Password Field show it for editing
    
    self.textFieldHiddenPassword.onBecomesFirstResponder = ^{
        self.showPassword = YES;
        [self showOrHidePassword];
    };
    
    self.showPassword = Settings.sharedInstance.alwaysShowPassword;
    
    self.attachments = [NSArray array];
    self.attachmentsView.dataSource = self;
    self.attachmentsView.delegate = self;
    
    self.attachmentsView.onSpaceBar = self.attachmentsView.onDoubleClick = ^{ // Funky
        [self onPreviewAttachment:nil];
    };
    
    // Summary Table
    
    self.tableViewSummary.dataSource = self;
    self.tableViewSummary.delegate = self;
    
    // Custom Fields
    
    self.customFields = [NSArray array];
    self.tableViewCustomFields.dataSource = self;
    self.tableViewCustomFields.delegate = self;

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
    model.onModelChanged = ^{
        //NSLog(@"OnModelChanged...");
        [self refreshOutlineAndDetailsPaneNoSelectionChange];
    };
    
    [self bindToModel];
}

//-(void)updateDocumentUrl {
//    [self bindDetailsPane];
//}

- (BOOL)biometricOpenIsAvailableForSafe {
    SafeMetaData* metaData = [self getSafeMetaData];
    
    return  metaData == nil ||
            !metaData.isTouchIdEnabled ||
            !(metaData.touchIdPassword || metaData.touchIdKeyFileDigest) ||
            !BiometricIdHelper.sharedInstance.biometricIdAvailable ||
    !(Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial);
}

- (void)bindToModel {
    if(self.model == nil) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:2];
        [self.outlineView reloadData];
        return;
    }
    
    if(self.model.locked) {
        [self.tabViewLockUnlock selectTabViewItemAtIndex:0];
        
        if([self biometricOpenIsAvailableForSafe]) {
            self.buttonUnlockWithTouchId.hidden = YES;
            [self.buttonUnlockWithTouchId setKeyEquivalent:@""];
            [self.buttonUnlockWithPassword setKeyEquivalent:@"\r"];
        }
        else {
            self.buttonUnlockWithTouchId.hidden = NO;
            [self.buttonUnlockWithTouchId setKeyEquivalent:@"\r"];
            [self.buttonUnlockWithPassword setKeyEquivalent:@""];        }
    }
    else {        
        [self.tabViewLockUnlock selectTabViewItemAtIndex:1];
    }
    
    NSInteger colIdx = [self.outlineView columnWithIdentifier:@"UsernameColumn"];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    col.hidden = !Settings.sharedInstance.alwaysShowUsernameInOutlineView;

    [self.outlineView reloadData];
    
    [self bindDetailsPane];
}

- (void)setInitialFocus {
    if(self.model == nil || self.model.locked) {
        if([self biometricOpenIsAvailableForSafe]) {
            [self.view.window makeFirstResponder:self.textFieldMasterPassword];
        }
        else {
            [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
        }
    }
    else {
        [self.view.window makeFirstResponder:self.outlineView];
    }
}

- (void)refreshAttachments:(Node *)it {
    self.attachments = [it.fields.attachments copy];
    [self.attachmentsView reloadData];
}

- (void)refreshCustomFields:(Node *)it {
    NSArray<NSString*> *sortedKeys = [it.fields.customFields.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    
    NSMutableArray *fields = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        NSString* value = it.fields.customFields[key];
        
        CustomField* field = [[CustomField alloc] init];
        field.key = key;
        field.value = value;
        [fields addObject:field];
    }
    
    self.customFields = [fields copy];
    [self.tableViewCustomFields reloadData];
}

- (void)bindDetailsPane {
    Node* it = [self getCurrentSelectedItem];
    
    [self updateAutocompleteCaches];
    
    if(!it) {
        [self.tabViewRightPane selectTabViewItemAtIndex:2];
        [self.tableViewSummary reloadData];
    }
    else if (it.isGroup) {
        [self.tabViewRightPane selectTabViewItemAtIndex:1];
        self.imageViewGroupDetails.image = [self getIconForNode:it large:YES];
        self.textFieldSummaryTitle.stringValue = it.title;
    }
    else {
        self.emailRow.hidden = self.model.format != kPasswordSafe;
        self.attachmentsRow.hidden = self.model.format == kPasswordSafe;
        self.customFieldsRow.hidden = self.model.format == kPasswordSafe || self.model.format == kKeePass1;
        
        //NSLog(@"Setting Text fields");
        self.textFieldTitle.stringValue = it.title;
        self.textFieldPw.stringValue = it.fields.password;
        self.textFieldUrl.stringValue = it.fields.url;
        self.comboboxUsername.stringValue = it.fields.username;
        self.comboBoxEmail.stringValue = it.fields.email;
        self.textViewNotes.string = it.fields.notes;
        self.textFieldSummaryTitle.stringValue = it.title;

        if([Settings sharedInstance].revealDetailsImmediately) {
            [self revealDetails];
        }
        else {
            [self concealDetails];
        }
        
        [self refreshAttachments:it];
        
        [self refreshCustomFields:it];
        
        self.showPassword = Settings.sharedInstance.alwaysShowPassword;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Collection View - Attachments

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.attachments.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    AttachmentItem *item = [self.attachmentsView makeItemWithIdentifier:@"AttachmentItem" forIndexPath:indexPath];
 
    NodeFileAttachment* attachment = self.attachments[indexPath.item];
    DatabaseAttachment* dbAttachment = self.model.attachments[attachment.index];

    item.textField.stringValue = attachment.filename;
    item.imageView.image = kDefaultAttachmentIcon;
    item.labelFileSize.stringValue = [NSByteCountFormatter stringFromByteCount:dbAttachment.data.length countStyle:NSByteCountFormatterCountStyleFile];
    
    if(self.attachmentsIconCache == nil) {
        self.attachmentsIconCache = [NSMutableDictionary dictionary];
        [self buildAttachmentsIconCache];
    }
    
    NSImage* cachedIcon = self.attachmentsIconCache[@(attachment.index)];
    if(cachedIcon) {
        item.imageView.image = cachedIcon;
    }
    else {
        NSImage* img = [[NSWorkspace sharedWorkspace] iconForFileType:attachment.filename];
        
        if(img.size.width != 32 || img.size.height != 32) {
            img = scaleImage(img, CGSizeMake(32, 32));
        }
        
        item.imageView.image = img;
    }
    
    return item;
}

- (void)buildAttachmentsIconCache {
    NSArray *workingCopy = [self.model.attachments copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0;i<workingCopy.count;i++) {
            DatabaseAttachment* dbAttachment = workingCopy[i];
            
            NSImage* img = [[NSImage alloc] initWithData:dbAttachment.data];
            if(img) {
                img = scaleImage(img, CGSizeMake(32, 32));
                [self.attachmentsIconCache setObject:img forKey:@(i)];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.attachmentsView reloadData];
            [self.view setNeedsDisplay:YES];
        });
    });
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (IBAction)onPreviewAttachment:(id)sender {
    NSUInteger index = [self.attachmentsView.selectionIndexes firstIndex];
    if(index == NSNotFound) {
        return;
    }
    
    [QLPreviewPanel.sharedPreviewPanel makeKeyAndOrderFront:self];
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return 0;
    }
    
    return 1;
}

- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    if(index != 0) {
        return nil;
    }
    
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return nil;
    }
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    
    if(nodeAttachment.index < 0 || nodeAttachment.index >= self.model.attachments.count) {
        NSLog(@"Node Attachment out of bounds of Database Attachments. [%d]", nodeAttachment.index);
        return nil;
    }
    
    DatabaseAttachment* dbAttachment = [self.model.attachments objectAtIndex:nodeAttachment.index];
    
    NSString* f = [NSTemporaryDirectory() stringByAppendingPathComponent:nodeAttachment.filename];
    [dbAttachment.data writeToFile:f atomically:YES];
    NSURL* url = [NSURL fileURLWithPath:f];
    
    return url;
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
    return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
    panel.dataSource = self;
    panel.delegate = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        NSString* path = [NSString pathWithComponents:@[NSTemporaryDirectory(), file]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    }
}

- (IBAction)onSaveAttachment:(id)sender {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    
    if(nodeAttachment.index < 0 || nodeAttachment.index >= self.model.attachments.count) {
        NSLog(@"Node Attachment out of bounds of Database Attachments. [%d]", nodeAttachment.index);
        return;
    }
    
    // Save As Dialog...
    
    NSSavePanel * savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = nodeAttachment.filename;
    
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            DatabaseAttachment* dbAttachment = [self.model.attachments objectAtIndex:nodeAttachment.index];
            [dbAttachment.data writeToFile:savePanel.URL.path atomically:YES];
            [savePanel orderOut:self];
        }
    }];
}

- (IBAction)onRemoveAttachment:(id)sender {
    NSUInteger idx = [self.attachmentsView.selectionIndexes firstIndex];
    if(idx == NSNotFound) {
        return;
    }
    
    NodeFileAttachment* nodeAttachment = self.attachments[idx];
    NSString* prompt = [NSString stringWithFormat:@"Are you sure you want to remove the attachment: %@?", nodeAttachment.filename];
    [Alerts yesNo:prompt window:self.view.window completion:^(BOOL yesNo) {
        if(yesNo) {
            Node* node = [self getCurrentSelectedItem];
            [self.model removeItemAttachment:node atIndex:idx];
            
            self.attachmentsIconCache = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refreshAttachments:node];
            });
        }
    }];
}

- (IBAction)onAddAttachment:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"Add: %@", openPanel.URL);

            Node* node = [self getCurrentSelectedItem];
            
            NSError* error;
            NSData* data = [NSData dataWithContentsOfURL:openPanel.URL options:kNilOptions error:&error];
            
            if(!data) {
                NSLog(@"Could not read file at %@. Error: %@", openPanel.URL, error);
                return;
            }
            
            NSString* filename = openPanel.URL.lastPathComponent;
            
            [self.model addItemAttachment:node attachment:[[UiAttachment alloc] initWithFilename:filename data:data]];
            
            self.attachmentsIconCache = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self refreshAttachments:node];
            });
        }
    }];
}

// FUTURE: Drag and Drop attachments to/from

//- (NSDragOperation)collectionView:(NSCollectionView *)collectionView validateDrop:(id<NSDraggingInfo>)draggingInfo proposedIndex:(NSInteger *)proposedDropIndex dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation {
//
//}
//
//- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id<NSDraggingInfo>)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation {
//
//}
//
//- (BOOL)collectionView:(NSCollectionView *)collectionView writeItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths toPasteboard:(NSPasteboard *)pasteboard {
//
//}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    
    BOOL searchAll = NO;
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
        searchAll = YES;
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@  "
                 @"OR fields.password contains[c] %@  "
                 @"OR fields.username contains[c] %@  "
                 @"OR fields.email contains[c] %@  "
                 @"OR fields.url contains[c] %@  "
                 @"OR fields.notes contains[c] %@",
                     searchText, searchText, searchText, searchText, searchText, searchText];
    
        // Future: Attachments?!
    }

    if([predicate evaluateWithObject:item]) {
        return YES;
    }
    else if(searchAll && (self.model.format == kKeePass4 || self.model.format == kKeePass)) {
        for (NSString* key in item.fields.customFields.allKeys) {
            NSString* value = item.fields.customFields[key];
            
            if([key rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound ||
               [value rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return YES;
            }
        }
    }
    
    if(item.isGroup && recurse) {
        for(Node* child in item.children) {
            //if(child.isGroup) {
                //if([[self getSafeItems:child] count] > 0) {
                   // return YES;
                //}
            //}
            //else {
                if([self isSafeItemMatchesSearchCriteria:child recurse:YES]) {
                    return YES;
                }
            //}
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
    if([tableColumn.identifier isEqualToString:@"TitleColumn"]) {
        NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"TitleCell" owner:self];

        Node *it = (Node*)item;
        
        cell.textField.stringValue = it.title;
        cell.imageView.objectValue = [self getIconForNode:it large:NO];
        
        return cell;
    }
    else {
        NSTableCellView* cell = (NSTableCellView*)[outlineView makeViewWithIdentifier:@"UsernameCell" owner:self];
        
        Node *it = (Node*)item;
        
        cell.textField.stringValue = it.fields.username;
        
        return cell;
    }
}

- (NSImage * )getIconForNode:(Node *)vm large:(BOOL)large {
    NSImage* ret;
    
    if(self.model.format == kPasswordSafe) {
        if(!large) {
            ret = vm.isGroup ? kSmallYellowFolderImage : kSmallLockImage;
        }
        else {
            ret = vm.isGroup ? kFolderImage : kSmallLockImage;
        }
    }
    else {
        ret = vm.isGroup ? kKeePassIconSet[48] : kKeePassIconSet[0];
    }
    
    // KeePass Specials
    
    if(vm.customIconUuid) {
        NSData* data = self.model.customIcons[vm.customIconUuid];
        
        if(data) {
            NSImage* img = [[NSImage alloc] initWithData:data]; // FUTURE: Cache
            if(img) {
                NSImage *resized = scaleImage(img, CGSizeMake(48, 48)); // FUTURE: Scale up if large? THis is only used on details pane
                return resized;
            }
        }
    }
    else if(vm.iconId && vm.iconId.intValue >= 0 && vm.iconId.intValue < kKeePassIconSet.count) {
        ret = kKeePassIconSet[vm.iconId.intValue];
    }

    return ret;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    //NSLog(@"Selection Change Outline View");
    [self bindDetailsPane];
}

- (IBAction)onUseKeyFileOnly:(id)sender {
    [self onUseKeyFileCommon:nil];
}

- (IBAction)onUseKeyFile:(id)sender {
    [self onUseKeyFileCommon:self.textFieldMasterPassword.stringValue];
}

- (void)onUseKeyFileCommon:(NSString*)password {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"Open Key File: %@", openPanel.URL);
            
            NSError* error;
            NSData* data = [NSData dataWithContentsOfURL:openPanel.URL options:kNilOptions error:&error];
            
            if(!data) {
                NSLog(@"Could not read file at %@. Error: %@", openPanel.URL, error);
                [Alerts error:@"Could not open key file." error:error window:self.view.window];
                return;
            }
            
            NSData* keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data];
            [self unlock:password keyFileDigest:keyFileDigest isBiometricOpen:NO];
        }
    }];
}

- (IBAction)onEnterMasterPassword:(id)sender {
    [self unlock:self.textFieldMasterPassword.stringValue keyFileDigest:nil isBiometricOpen:NO];
}

- (IBAction)onUnlockWithTouchId:(id)sender {
    if(BiometricIdHelper.sharedInstance.biometricIdAvailable) {
        SafeMetaData *safe = [self getSafeMetaData];
        
        if(safe && safe.isTouchIdEnabled && (safe.touchIdPassword || safe.touchIdKeyFileDigest)) {
            [BiometricIdHelper.sharedInstance authorize:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(success) {
                        [self unlock:safe.touchIdPassword keyFileDigest:safe.touchIdKeyFileDigest isBiometricOpen:YES];
                    }
                    else {
                        NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                        
                        if(error && (error.code == LAErrorUserFallback || error.code == LAErrorUserCancel)) {
                            NSLog(@"User cancelled or selected fallback. Ignore...");
                        }
                        else {
                            [Alerts error:error window:self.view.window];
                        }
                    }
                });}];
        }
        else {
            NSLog(@"Touch ID button pressed but no Touch ID Stored?");
            [Alerts info:@"The stored credentials are unavailable. Please enter the password manually. Touch ID Metadata for this safe will be cleared." window:self.view.window];
            if(safe) {
                [SafesList.sharedInstance remove:safe.uuid];
            }
        }
    }
}

- (SafeMetaData*)getSafeMetaData {
    if(!self.model || !self.model.fileUrl) {
        return nil;
    }
    
    return [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.fileIdentifier isEqualToString:self.model.fileUrl.absoluteString];
    }];
}

- (void)onSuccessfulUnlock:(NSString *)selectedItemId password:(NSString*)password keyFileDigest:(NSData*)keyFileDigest {
    if ( BiometricIdHelper.sharedInstance.biometricIdAvailable && (Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial)) {
        //NSLog(@"Biometric ID is available on Device. Should we enrol?");
        
        if(!Settings.sharedInstance.warnedAboutTouchId) {
            Settings.sharedInstance.warnedAboutTouchId = YES;
            
            [Alerts info:@"Touch ID Considerations\n\nWhile this is very convenient, it is not a perfect system for protecting your passwords. It is provided for convenience only. It is within the realm of possibilities that someone with access to your device or your fingerprint, can produce a good enough fake fingerprint to fool Apple’s Touch ID. In addition, on your Mac, your master password will be securely stored in the Keychain. This means it is possible for someone with administrative privileges to search your Keychain for your master password. You should be aware that a strong passphrase held only in your mind provides the most secure experience with StrongBox.\n\nPlease take all of this into account, and make your decision to use Touch ID based on your preferred balance of convenience and security."
                  window:self.view.window];
        }
        
        SafeMetaData* metaData = [self getSafeMetaData];
        
        if(!metaData) {
            // First Time? Display Touch ID Caveat
            
            NSString* message = [NSString stringWithFormat:@"Would you like to use %@ to open this safe in the future?", BiometricIdHelper.sharedInstance.biometricIdName];
            
            [Alerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                NSURL* url = self.model.fileUrl;
                SafeMetaData* safeMetaData = [[SafeMetaData alloc] initWithNickName:[url.lastPathComponent stringByDeletingPathExtension]
                                                                    storageProvider:kLocalDevice
                                                                           fileName:url.lastPathComponent
                                                                     fileIdentifier:url.absoluteString];
                
                if(yesNo) {
                    safeMetaData.isTouchIdEnabled = YES;
                    safeMetaData.touchIdPassword = password;
                    safeMetaData.touchIdKeyFileDigest = keyFileDigest;
                }
                else {
                    safeMetaData.isTouchIdEnabled = NO;
                }
                
                [SafesList.sharedInstance add:safeMetaData];
                
                [self openSafeForDisplayAfterUnlock:selectedItemId];
            }];
        }
        else {
            NSLog(@"Found meta data for this file, no need to enrol.");
            [self openSafeForDisplayAfterUnlock:selectedItemId];
        }
    }
    else {
        [self openSafeForDisplayAfterUnlock:selectedItemId];
    }
}

- (void)openSafeForDisplayAfterUnlock:(NSString *)selectedItemId {
    [self bindToModel];
    
    self.textFieldMasterPassword.stringValue = @"";
    
    Node* selectedItem = [self.model getItemFromSerializationId:selectedItemId];
    
    [self selectItem:selectedItem];
    
    [self setInitialFocus];
}

- (void)showProgressModal:(NSString*)operationDescription {
    [self hideProgressModal];
    
    self.progressWindow = [[ProgressWindow alloc] initWithWindowNibName:@"ProgressWindow"];
    self.progressWindow.operationDescription = operationDescription;
    [self.view.window beginSheet:self.progressWindow.window  completionHandler:nil];
}

- (void)hideProgressModal {
    if(self.progressWindow) {
        [self.view.window endSheet:self.progressWindow.window];
        self.progressWindow = nil;
    }
}

- (void)unlock:(NSString*)password keyFileDigest:(NSData*)keyFileDigest isBiometricOpen:(BOOL)isBiometricOpen {
    if(self.model && self.model.locked) {
        [self showProgressModal:@"Decrypting..."];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error;
            NSString *selectedItemId;

            BOOL ret = [self.model unlock:password keyFileDigest:keyFileDigest selectedItem:&selectedItemId error:&error];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onUnlockDone:ret selectedItemId:selectedItemId password:password
                     keyFileDigest:keyFileDigest isBiometricOpen:isBiometricOpen error:error];
            });
        });
    }
}

- (void)onUnlockDone:(BOOL)success
      selectedItemId:(NSString*)selectedItemId
            password:(NSString*)password
       keyFileDigest:(NSData*)keyFileDigest
     isBiometricOpen:(BOOL)isBiometricOpen
               error:(NSError*)error {
    [self hideProgressModal];
    
    if(success) {
        [self onSuccessfulUnlock:selectedItemId password:password keyFileDigest:keyFileDigest];
    }
    else {
        if(!isBiometricOpen) {
            if(error) {
                [Alerts error:@"Could not open safe" error:error window:self.view.window];
            }
        }
        else {
            if(error) {
                SafeMetaData *safe = [self getSafeMetaData];
                
                safe.touchIdPassword = nil;
                safe.touchIdKeyFileDigest = nil;
                [SafesList.sharedInstance remove:safe.uuid];
                
                [Alerts error:@"Could not open safe with stored Touch ID Credentials. The stored credentials will now be removed from secure storage. You will need to enter the correct credentials to unlock the safe, and enrol again for Touch ID." error:error window:self.view.window];
                
                [self bindToModel];
            }
        }
    }
}

- (void)onAutoLock:(NSNotification*)notification {
    if(self.model && !self.model.locked && !self.model.dirty) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLock:nil];
        });
    }
}

- (IBAction)onLock:(id)sender {
    if(self.model && !self.model.locked) {
        NSLog(@"isDocumentEdited: %d", [self.model.document isDocumentEdited]);
        if([self.model.document isDocumentEdited]) {
            [Alerts yesNo:@"You cannot lock a safe while changes are pending. Save changes and lock now?" window:self.view.window completion:^(BOOL yesNo) {
                if(yesNo) {
                    [self showProgressModal:@"Locking..."];
                    [self.model.document saveDocumentWithDelegate:self didSaveSelector:@selector(lockSafeContinuation:) contextInfo:nil];
                }
                else {
                    return;
                }
            }];
        }
        else {
            [self showProgressModal:@"Locking..."];

            [self lockSafeContinuation:nil];
        }
    }
}

- (IBAction)lockSafeContinuation:(id)sender {
    Node* item = [self getCurrentSelectedItem];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError* error;
        BOOL lockSuccess = [self.model lock:&error selectedItem:item.serializationId];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onLockDone:lockSuccess error:error];
        });
    });
}

- (void)onLockDone:(BOOL)lockSuccess error:(NSError*)error {
    [self hideProgressModal];

    if(!lockSuccess) {
        [Alerts error:error window:self.view.window];
        return;
    }
    
    [self bindToModel];
    
    self.textFieldMasterPassword.stringValue = @"";
    [self setInitialFocus];
    
    [self.view setNeedsDisplay:YES];
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

- (void)promptForMasterPassword:(BOOL)new completion:(void (^)(BOOL okCancel))completion {
    if(self.model && !self.model.locked) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.changeMasterPassword = [[CreateFormatAndSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
            
            self.changeMasterPassword.titleText = new ? @"Please Enter the Master Credentials for this Safe" : @"Change Master Credentials";
            self.changeMasterPassword.databaseFormat = self.model.format;
            
            [self.view.window beginSheet:self.changeMasterPassword.window  completionHandler:^(NSModalResponse returnCode) {
                if(returnCode == NSModalResponseOK) {
                    [self.model setMasterCredentials:self.changeMasterPassword.confirmedPassword masterKeyFileDigest:self.changeMasterPassword.confirmedKeyFileDigest];
                }
                
                if(completion) {
                    completion(returnCode == NSModalResponseOK);
                }
            }];
        });
    }
}

- (IBAction)onChangeMasterPassword:(id)sender {
    [self promptForMasterPassword:NO completion:^(BOOL okCancel) {
        if(okCancel) {
            [[NSApplication sharedApplication] sendAction:@selector(saveDocument:) to:nil from:self];
            [Alerts info:@"Master Credentials Changed and Safe Saved" window:self.view.window];
        }
    }];
}

- (IBAction)onSearch:(id)sender {
    //NSLog(@"Search For: %@", self.searchField.stringValue);
    
    Node* currentSelection = [self getCurrentSelectedItem];
    
    [self.outlineView reloadData];
    
    NSInteger colIdx = [self.outlineView columnWithIdentifier:@"UsernameColumn"];
    NSTableColumn *col = [self.outlineView.tableColumns objectAtIndex:colIdx];
    
    if( self.searchField.stringValue.length > 0) {
        col.hidden = NO;
        
        // Select first match...
        
        [self.outlineView expandItem:nil expandChildren:YES];

        for(int i=0;i < [self.outlineView numberOfRows];i++) {
            //NSLog(@"Searching: %d", i);
            Node* node = [self.outlineView itemAtRow:i];

            if([self isSafeItemMatchesSearchCriteria:node recurse:NO]) {
                //NSLog(@"Found: %@", node.title);
                [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: i] byExtendingSelection: NO];
                break;
            }
        }
    }
    else {
        col.hidden = !Settings.sharedInstance.alwaysShowUsernameInOutlineView;
        
        // Search cleared - can we maintain the selection?
        
        [self selectItem:currentSelection];
    }
    
    [self bindDetailsPane];
}

- (IBAction)onCheckboxRevealDetailsImmediately:(id)sender {
    [Settings sharedInstance].revealDetailsImmediately = self.checkboxRevealDetailsImmediately.state;
}

- (IBAction)onToggleShowHidePassword:(id)sender {
    self.showPassword = !self.showPassword;
    
    if(!self.showPassword) {
        // Shift Focus out of "Disabled" Password Text Field - otherwise we get a weird setup and passwords can be set to asterisks
        
        [self.textFieldPw resignFirstResponder];
        [self.textFieldTitle becomeFirstResponder];
    }
    
    [self showOrHidePassword];
}

- (void)showOrHidePassword {
    Node* item = [self getCurrentSelectedItem];
    if(!item)
    {
        return;
    }
    
    if(self.showPassword) {
        self.textFieldHiddenPassword.hidden = YES;
        self.textFieldPw.hidden = NO;
    }
    else {
        self.textFieldHiddenPassword.hidden = NO;
        self.textFieldPw.hidden = YES;
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

- (IBAction)onCopyEmail:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.comboBoxEmail.stringValue forType:NSStringPboardType];
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
    
    Node* item = [self getCurrentSelectedItem];
    
    NSString *password = item.fields.password;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (Node*)getCurrentSelectedItem {
    NSInteger selectedRow = [self.outlineView selectedRow];
    
    //NSLog(@"Selected Row: %ld", (long)selectedRow);
    
    return [self.outlineView itemAtRow:selectedRow];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    NSArray<NSString*>* src = aComboBox == self.comboboxUsername ? self.usernameAutoCompleteCache : self.emailAutoCompleteCache;
    return src.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    NSArray<NSString*>* src = aComboBox == self.comboboxUsername ? self.usernameAutoCompleteCache : self.emailAutoCompleteCache;
    return [src objectAtIndex:index];
}

- (void)textDidEndEditing:(NSNotification *)notification {
    //NSLog(@"textDidEndEditing: %@", notification);
    
    if(notification.object == self.textViewNotes) {
        [self bindModelToSimpleUiFields];
    }
}

-(void)controlTextDidEndEditing:(NSNotification *)obj {
   // NSLog(@"controlTextDidEndEditing: %@", obj);
    
    [self bindModelToSimpleUiFields];
}

- (IBAction)bindModelToSimpleUiFields {
    if(self.model.locked) { // Can happen when user hits Lock in middle of edit...
        return;
    }
    
    Node* item = [self getCurrentSelectedItem];

    if(!item || item.isGroup) {
        return;
    }

    if(![item.title isEqualToString:trimField(self.textFieldTitle)]) {
        [self.model setItemTitle:item title:trimField(self.textFieldTitle)];
    }
    
    if(![item.fields.username isEqualToString:trimField(self.comboboxUsername)]) {
        [self.model setItemUsername:item username:trimField(self.comboboxUsername)];
    }
    
    if(![item.fields.email isEqualToString:trimField(self.comboBoxEmail)]) {
        [self.model setItemEmail:item email:trimField(self.comboBoxEmail)];
    }
    
    if(![item.fields.url isEqualToString:trimField(self.textFieldUrl)]) {
        [self.model setItemUrl:item url:trimField(self.textFieldUrl)];
    }
    
    if(![item.fields.password isEqualToString:trimField(self.textFieldPw)]) {
        [self.model setItemPassword:item password:trimField(self.textFieldPw)];
    }
    
    NSString *updated = [NSString stringWithString:self.textViewNotes.textStorage.string];
    if(![item.fields.notes isEqualToString:updated]) {
        [self.model setItemNotes:item notes:updated];
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
        [self.model setItemTitle:item title:newTitle];
    }
    else {
        textField.stringValue = newTitle;
    }
}

- (IBAction)saveDocument:(id)sender {
    Node* item = [self getCurrentSelectedItem];
    
    if(item && !item.isGroup) {
        // We could be in process of editing a simple field in the details panel...
        
        [self bindModelToSimpleUiFields];
    }
    
    [self.model.document saveDocument:sender];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
    
    //NSLog(@"acceptDrop Move [%@] -> [%@]", sourceItem, destinationItem);
    
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
    
    if(!newItem) {
        [Alerts info:@"You cannot create a new record here. It must be within an existing folder." window:self.view.window];
        return;
    }
    
    self.searchField.stringValue = @""; // Clear any ongoing search...
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.showPassword = YES;
            [self showOrHidePassword];
            [self.view.window makeFirstResponder:self.textFieldTitle];
        });
    }
}

- (IBAction)onCreateGroup:(id)sender {
    Node *item = [self getCurrentSelectedItem];
    Node *parent = item && item.isGroup ? item : (item ? item.parent : self.model.rootGroup);

    Node *newItem = [self.model addNewGroup:parent];
    
    self.searchField.stringValue = @""; // Clear any ongoing search...
    
    [self.outlineView reloadData];
    
    NSInteger row = [self findRowForItemExpandIfNecessary:newItem];
    
    if(row < 0) {
        NSLog(@"Could not find newly added item?");
    }
    else {
        [self.outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: row] byExtendingSelection: NO];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSTableCellView* cellView = (NSTableCellView*)[self.outlineView viewAtColumn:0 row:row makeIfNecessary:YES];
            if ([cellView.textField acceptsFirstResponder]) {
                [cellView.window makeFirstResponder:cellView.textField];
            }
        });
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
    
    Node* item = [self getCurrentSelectedItem];
    NSString *password = item.fields.password;
    [[NSPasteboard generalPasteboard] setString:password forType:NSStringPboardType];

    [self onLaunchUrl:sender];
}

- (IBAction)onCopyDiagnosticDump:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *dump = [self.model description];
    
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
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onChangeMasterPassword:) ||
             theAction == @selector(onCopyAsCsv:) ||
             theAction == @selector(onCopyDiagnosticDump:) ||
             theAction == @selector(onImportFromCsvFile:) ||
             theAction == @selector(onLock:)) {
        return self.model && !self.model.locked;
    }
    else if (theAction == @selector(onShowSafeSummary:)) {
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
    else if (theAction == @selector(onCopyEmail:)) {
        return item && !item.isGroup && self.comboBoxEmail.stringValue.length;
    }
    else if (theAction == @selector(onCopyPasswordAndLaunchUrl:)) {
        return item && !item.isGroup && item.fields.password.length && self.textFieldUrl.stringValue.length;
    }
    else if (theAction == @selector(onCopyPassword:)) {
        return item && !item.isGroup && item.fields.password.length;
    }
    else if (theAction == @selector(onCopyNotes:)) {
        return item && !item.isGroup && self.textViewNotes.textStorage.string.length;
    }
    else if (theAction == @selector(onClearTouchId:)) {
        SafeMetaData* metaData = [self getSafeMetaData];
        return metaData != nil && BiometricIdHelper.sharedInstance.biometricIdAvailable;
    }
    else if (theAction == @selector(onPreviewAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }
    else if (theAction == @selector(onSaveAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }
    else if (theAction == @selector(onRemoveAttachment:)) {
        return [self.attachmentsView.selectionIndexes count] != 0;
    }
    else if (theAction == @selector(saveDocument:)) {
        return !self.model.locked;
    }
    
    return YES;
}

- (IBAction)onClearTouchId:(id)sender {
    SafeMetaData* metaData = [self getSafeMetaData];
    
    if(metaData) {
        [SafesList.sharedInstance remove:metaData.uuid];

        metaData.touchIdKeyFileDigest = nil;
        metaData.touchIdPassword = nil;
        
        [self bindToModel];
    }
}

- (IBAction)onGenerate:(id)sender {
    self.showPassword = YES;
    [self showOrHidePassword];

    self.textFieldPw.stringValue = [self.model generatePassword];
    
    [self bindModelToSimpleUiFields];
}

- (IBAction)onCopyAsCsv:(id)sender {
    [[NSPasteboard generalPasteboard] clearContents];
    
    NSString *newStr = [[NSString alloc] initWithData:[Csv getSafeAsCsv:self.model.rootGroup] encoding:NSUTF8StringEncoding];
    
    [[NSPasteboard generalPasteboard] setString:newStr forType:NSStringPboardType];
}

- (NSURL*)getFileThroughFileOpenDialog
{  
    NSOpenPanel * panel = [NSOpenPanel openPanel];
    [panel setTitle:@"Choose CSV file to Import"];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setFloatingPanel:NO];
    [panel setDirectoryURL:[NSURL fileURLWithPath:NSHomeDirectory()]];
     panel.allowedFileTypes = @[@"csv"];

    NSInteger result = [panel runModal];
    if(result == NSModalResponseOK)
    {
        return [[panel URLs] firstObject];
    }
    
    return nil;
}

- (IBAction)onImportFromCsvFile:(id)sender {
    NSString* message = [NSString stringWithFormat:@"The CSV file must contain a header row with at least one of the following fields:\n\n[%@, %@, %@, %@, %@, %@]\n\nThe order of the fields doesn't matter.", kCSVHeaderTitle, kCSVHeaderUsername, kCSVHeaderEmail, kCSVHeaderPassword, kCSVHeaderUrl, kCSVHeaderNotes];
   
    [Alerts info:@"CSV Format" informativeText:message window:self.view.window completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{[self importFromCsvFile];});
    }];
}

- (void)importFromCsvFile {
    NSURL* url = [self getFileThroughFileOpenDialog];
        
    if(url) {
        NSError *error = nil;
        NSArray *rows = [NSArray arrayWithContentsOfCSVURL:url options:CHCSVParserOptionsSanitizesFields | CHCSVParserOptionsUsesFirstLineAsKeys];
        
        if (rows == nil) {
            //something went wrong; log the error and exit
            NSLog(@"error parsing file: %@", error);
            [Alerts error:error window:self.view.window];
            return;
        }
        else if(rows.count == 0){
            [Alerts info:@"CSV File Contains Zero Rows. Cannot Import." window:self.view.window];
        }
        else {
            CHCSVOrderedDictionary *firstRow = [rows firstObject];
            
            if([firstRow objectForKey:kCSVHeaderTitle] ||
               [firstRow objectForKey:kCSVHeaderUsername] ||
               [firstRow objectForKey:kCSVHeaderUrl] ||
               [firstRow objectForKey:kCSVHeaderEmail] ||
               [firstRow objectForKey:kCSVHeaderPassword] ||
               [firstRow objectForKey:kCSVHeaderNotes]) {
                NSString* message = [NSString stringWithFormat:@"Found %lu valid rows in CSV file. Are you sure you would like to import now?", (unsigned long)rows.count];
                
                [Alerts yesNo:message window:self.view.window completion:^(BOOL yesNo) {
                    if(yesNo) {
                        [self.model importRecordsFromCsvRows:rows];
                        
                        [Alerts info:@"CSV File Successfully Imported." window:self.view.window];
                        
                        [self bindToModel];
                    }
                }];
            }
            else {
                [Alerts info:@"No valid rows found. Ensure CSV file contains a header row and at least one of the required fields." window:self.view.window];
            }
        }
    }
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

- (IBAction)onPasswordPreferences:(id)sender {
    [PreferencesWindowController.sharedInstance showOnTab:1];
}

- (void)onPreferencesChanged:(NSNotification*)notification {
    //NSLog(@"Preferences Have Changed Notification Received... Refreshing View.");
    
    [self refreshOutlineAndDetailsPaneNoSelectionChange];
}

- (void)refreshOutlineAndDetailsPaneNoSelectionChange {
    //NSInteger selectedRow = [self.outlineView selectedRow];
    
    Node* currentSelection = [self getCurrentSelectedItem];
    
    [self.outlineView reloadData];
    
    self.attachmentsIconCache = nil;
    [self.attachmentsView reloadData];
    [self.tableViewCustomFields reloadData];
    
    [self selectItem:currentSelection];
}

static NSComparator finderStringComparator = ^(id obj1, id obj2)
{
    return [Utils finderStringCompare:obj1 string2:obj2];
};

static NSArray<NSImage*>* getKeePassIconSet() {
    NSArray<NSString*>* names = @[@"C00_Password",
                                  @"C01_Package_Network",
                                  @"C02_MessageBox_Warning",
                                  @"C03_Server",
                                  @"C04_Klipper",
                                  @"C05_Edu_Languages",
                                  @"C06_KCMDF",
                                  @"C07_Kate",
                                  @"C08_Socket",
                                  @"C09_Identity",
                                  @"C10_Kontact",
                                  @"C11_Camera",
                                  @"C12_IRKickFlash",
                                  @"C13_KGPG_Key3",
                                  @"C14_Laptop_Power",
                                  @"C15_Scanner",
                                  @"C16_Mozilla_Firebird",
                                  @"C17_CDROM_Unmount",
                                  @"C18_Display",
                                  @"C19_Mail_Generic",
                                  @"C20_Misc",
                                  @"C21_KOrganizer",
                                  @"C22_ASCII",
                                  @"C23_Icons",
                                  @"C24_Connect_Established",
                                  @"C25_Folder_Mail",
                                  @"C26_FileSave",
                                  @"C27_NFS_Unmount",
                                  @"C28_Message",
                                  @"C29_KGPG_Term",
                                  @"C30_Konsole",
                                  @"C31_FilePrint",
                                  @"C32_FSView",
                                  @"C33_Run",
                                  @"C34_Configure",
                                  @"C35_KRFB",
                                  @"C36_Ark",
                                  @"C37_KPercentage",
                                  @"C38_Samba_Unmount",
                                  @"C39_History",
                                  @"C40_Mail_Find",
                                  @"C41_VectorGfx",
                                  @"C42_KCMMemory",
                                  @"C43_Trashcan_Full",
                                  @"C44_KNotes",
                                  @"C45_Cancel",
                                  @"C46_Help",
                                  @"C47_KPackage",
                                  @"C48_Folder",
                                  @"C49_Folder_Blue_Open",
                                  @"C50_Folder_Tar",
                                  @"C51_Decrypted",
                                  @"C52_Encrypted",
                                  @"C53_Apply",
                                  @"C54_Signature",
                                  @"C55_Thumbnail",
                                  @"C56_KAddressBook",
                                  @"C57_View_Text",
                                  @"C58_KGPG",
                                  @"C59_Package_Development",
                                  @"C60_KFM_Home",
                                  @"C61_Services",
                                  @"C62_Tux",
                                  @"C63_Feather",
                                  @"C64_Apple",
                                  @"C65_W",
                                  @"C66_Money",
                                  @"C67_Certificate",
                                  @"C68_Smartphone"];
    
    return [names map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return [NSImage imageNamed:obj];
    }];
}

static BasicOrderedDictionary* getSummaryDictionary(ViewModel* model) {
    BasicOrderedDictionary *ret = [[BasicOrderedDictionary alloc] init];
    
    for (NSString* key in [model.metadata kvpForUi].allKeys) {
        NSString *value = [[model.metadata kvpForUi] objectForKey:key];
        [ret addKey:key andValue:value];
    }
    
    [ret addKey:@"Unique Usernames" andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.usernameSet.count]];
    [ret addKey:@"Unique Passwords" andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.passwordSet.count]];
    [ret addKey:@"Most Popular Username" andValue:model.mostPopularUsername ? model.mostPopularUsername : @"<None>"];
    [ret addKey:@"Number of Entries" andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.numberOfRecords]];
    [ret addKey:@"Number of Folders" andValue:[NSString stringWithFormat:@"%lu", (unsigned long)model.numberOfGroups]];
    
    return ret;
}

- (IBAction)onShowSafeSummary:(id)sender {
    [self.outlineView deselectAll:nil]; // Funky side effect, no selection -> show safe summary
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if(tableView == self.tableViewSummary) {
        BasicOrderedDictionary* dictionary = getSummaryDictionary(self.model);
        return dictionary.count;
    }
    else {
        return self.customFields.count;
    }
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView == self.tableViewSummary) {
        NSTableCellView* cell = [self.tableViewSummary makeViewWithIdentifier:@"KeyCellIdentifier" owner:nil];

        BasicOrderedDictionary *dict = getSummaryDictionary(self.model);
        
        
        NSString *key = dict.allKeys[row];
        NSString *value = [dict objectForKey:key];
        
        value = value == nil ? @"" : value; // Safety Only
        
        cell.textField.stringValue = [tableColumn.identifier isEqualToString:@"KeyColumn"] ? key : value;
        
        return cell;
    }
    else {
        NSString* cellId = [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"] ? @"CustomFieldKeyCellIdentifier" : @"CustomFieldValueCellIdentifier";
        
        NSTableCellView* cell = [self.tableViewCustomFields makeViewWithIdentifier:cellId owner:nil];

        // NB: Values are set with bindings using objectValueForTableColumn below...
        
        return cell;
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView != self.tableViewSummary) {
        CustomField* field = [self.customFields objectAtIndex:row];
        return [tableColumn.identifier isEqualToString:@"CustomFieldKeyColumn"] ? field.key : field.value;
    }
    else {
        return nil;
    }
}

- (IBAction)onEndCustomFieldKeyCellEditing:(id)sender {
    NSInteger row = self.tableViewCustomFields.selectedRow;
    NSTextField* textField = ((NSTextField*)sender);
    NSString* key = textField.stringValue;
    CustomField* oldField = self.customFields[row];
    
    if([key isEqualToString:oldField.key]) {
        return;
    }
    
    if(!key.length) {
        [Alerts info:@"You cannot have an empty Key here. Use the remove button to remove this field if you want." window:self.view.window];
        textField.stringValue = oldField.key;
        return;
    }
    
    NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
        return obj.key;
    }];
    
    NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
    const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
    
    if([existingKeySet containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it already exists in custom fields." window:self.view.window];
        textField.stringValue = oldField.key;
        return;
    }
        
    if([keePassReserved containsObject:key]) {
        [Alerts info:@"You cannot use that Key here as it is reserved for standard KeePass fields." window:self.view.window];
        textField.stringValue = oldField.key;
        return;
    }
    
    Node* item = [self getCurrentSelectedItem];
    
    [self.model removeCustomField:item key:oldField.key];
    [self.model setCustomField:item key:key value:oldField.value];
    
    [self refreshCustomFields:item];
}

- (IBAction)onEndCustomFieldValueCellEditing:(id)sender {
    NSInteger row = self.tableViewCustomFields.selectedRow;
    NSTextField* textField = ((NSTextField*)sender);
    NSString* value = textField.stringValue;
    CustomField* oldField = self.customFields[row];

    Node* item = [self getCurrentSelectedItem];
    
    [self.model setCustomField:item key:oldField.key value:value];
    
    [self refreshCustomFields:item];
}

- (IBAction)onRemoveCustomField:(id)sender {
    if(self.tableViewCustomFields.selectedRow != -1) {
        CustomField *field = self.customFields[self.tableViewCustomFields.selectedRow];
        
        [Alerts yesNo:@"Are you sure you want to remove this field?" window:self.view.window completion:^(BOOL yesNo) {
            if(yesNo) {
                Node* item = [self getCurrentSelectedItem];
                
                [self.model removeCustomField:item key:field.key];
                
                [self refreshCustomFields:item];
            }
        }];
    }
}

- (IBAction)onAddCustomField:(id)sender {
    Alerts* alert = [[Alerts alloc] init];
    
    [alert inputKeyValue:@"Enter New Custom Field" completion:^(BOOL yesNo, NSString *key, NSString *value) {
        if(yesNo) {
            NSArray<NSString*>* existingKeys = [self.customFields map:^id _Nonnull(CustomField * _Nonnull obj, NSUInteger idx) {
                return obj.key;
            }];
            
            NSSet<NSString*> *existingKeySet = [NSSet setWithArray:existingKeys];
            const NSSet<NSString*> *keePassReserved = [Entry reservedCustomFieldKeys];
            
            if([existingKeySet containsObject:key]) {
                [Alerts info:@"You cannot use that Key here as it already exists in custom fields." window:self.view.window];
                return;
            }
            
            if([keePassReserved containsObject:key]) {
                [Alerts info:@"You cannot use that Key here as it is reserved for standard KeePass fields." window:self.view.window];
                return;
            }

            Node* item = [self getCurrentSelectedItem];
            
            [self.model setCustomField:item key:key value:value];
            
            [self refreshCustomFields:item];
        }
    }];
}

@end
