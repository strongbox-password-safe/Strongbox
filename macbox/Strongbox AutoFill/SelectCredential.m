//
//  SelectCredential.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "SelectCredential.h"
#import "DatabaseSearchAndSorter.h"
#import "NodeIconHelper.h"
#import "EntryTableCellView.h"
#import "NSString+Extensions.h"
#import "CustomBackgroundTableView.h"
#import "OTPToken+Generation.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface SelectCredential () <NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate>

@property (weak) IBOutlet NSButton *buttonSelect;
@property (weak) IBOutlet CustomBackgroundTableView *tableView;
@property (weak) IBOutlet NSSearchField *searchField;

@property NSArray<Node*>* items;
@property NSArray<Node*>* searchResults;

@property BOOL viewWillAppearFirstTimeDone;
@property BOOL doneFirstAppearanceTasks;
@property (weak) IBOutlet NSTextField *cautionImpreciseWarning;

@property BOOL doneSmartInit;
@property (weak) IBOutlet NSButton *buttonCreateNew;

@property (nullable) NSTimer* otpTimer;

@end

@implementation SelectCredential

- (void)viewWillAppear {
    [super viewWillAppear];
    
    if ( !self.viewWillAppearFirstTimeDone ) {
        [self setupUI];
    }
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    if ( !self.doneFirstAppearanceTasks ) {
        self.doneFirstAppearanceTasks = YES;
        self.view.window.frameAutosaveName = @"SelectCredential-AutoSave";
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self smartInitializeSearch];
            
            [self.view.window makeFirstResponder:self.searchField];
            
            [self onSearch:nil];
        });
    }
    
    [self startOtpRefreshTimer];
}

- (void)viewDidDisappear {
    [super viewDidDisappear];
    
    [self stopOtpRefreshTimer];
}

- (void)setupUI {
    self.viewWillAppearFirstTimeDone = YES;
    
    NSString* loc = NSLocalizedString(@"mac_search_placeholder", @"Search (⌘F)");
    [self.searchField setPlaceholderString:loc];
    self.searchField.enabled = YES;
    self.searchField.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.doubleAction = @selector(onSelect:);
    
    [self.tableView registerNib:[[NSNib alloc] initWithNibNamed:kEntryTableCellViewIdentifier bundle:nil]
                  forIdentifier:kEntryTableCellViewIdentifier];
    
    [self.tableView sizeLastColumnToFit];
    
    [self bindSelectButton];
    
    [self loadItems];
    
    NSString *text = self.items.count ?
    NSLocalizedString(@"pick_creds_vc_empty_search_dataset_title", @"No Matching Entries") :
    NSLocalizedString(@"pick_creds_vc_empty_dataset_title", @"Empty Database");
    
    self.tableView.emptyString = text;
    self.cautionImpreciseWarning.hidden = YES;
    
    if (@available(macOS 13.0, *)) {
        self.buttonCreateNew.hidden = self.model.isReadOnly;
    }
    else {
        self.buttonCreateNew.hidden = YES;
    }
}

- (void)stopOtpRefreshTimer {
    if ( self.otpTimer ) {
        [self.otpTimer invalidate];
        self.otpTimer = nil;
    }
}

- (void)startOtpRefreshTimer {
    [self stopOtpRefreshTimer];
    
    self.otpTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                     target:self
                                                   selector:@selector(refreshOtpCodes)
                                                   userInfo:nil
                                                    repeats:YES];
}

- (void)refreshOtpCodes {
    NSScrollView* scrollView = self.tableView.enclosingScrollView;
    CGRect visibleRect = scrollView.contentView.visibleRect;
    NSRange rowRange = [self.tableView rowsInRect:visibleRect];

    if ( rowRange.length > 0 ) {
        NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange:rowRange];
        [self.tableView reloadDataForRowIndexes:indexSet columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}

- (IBAction)onSearch:(id)sender {
    [self filterContentForSearchText:self.searchField.stringValue scope:kSearchScopeAll];
    
    [self.tableView reloadData];
    
    if (self.tableView.numberOfRows > 0) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    
    [self bindSelectButton];
    
    if ( self.doneSmartInit ) {
        self.cautionImpreciseWarning.hidden = YES;
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if(control == self.searchField) { 
        if (commandSelector == @selector(moveDown:)) {
            slog(@"%@-%@-%@", control, textView, NSStringFromSelector(commandSelector));
            if (self.tableView.numberOfRows > 0) {
                [self.view.window makeFirstResponder:self.tableView];
                [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                return YES;
            }
        }
        else if (commandSelector == @selector(insertNewline:)) {
            
            
            [self onSelect:nil];
        }
    }

    return NO;
}

- (NSArray<Node *> *)getDataSource {
    return (self.searchField.stringValue.length ? self.searchResults : self.items);
}

- (void)loadItems {
    self.items = [self.model filterAndSortForBrowse:self.model.allSearchableNoneExpiredEntries.mutableCopy
                              includeKeePass1Backup:NO
                                  includeRecycleBin:NO
                                     includeExpired:NO
                                      includeGroups:NO
                                    browseSortField:kBrowseSortFieldTitle
                                         descending:NO
                                  foldersSeparately:YES];

    [self.tableView reloadData];
}



- (void)filterContentForSearchText:(NSString *)searchText scope:(SearchScope)scope {
    if(!searchText.length) {
        self.searchResults = self.items;
        return;
    }
    
    self.searchResults = [self getMatchingItems:searchText scope:scope];
}

- (void)smartInitializeSearch {
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = self.serviceIdentifiers;

    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = serviceId.identifier.urlExtendedParse;
            
            
            
            
            
            if (url) {
                NSArray* items = [self getMatchingItems:url.absoluteString scope:kSearchScopeUrl];
                if(items.count) {
                    self.searchField.stringValue = url.absoluteString;
                    return;
                }
                else {

                }
                
                
                
                if ( url.host.length ) { 
                    items = [self getMatchingItems:url.host scope:kSearchScopeUrl];
                    if(items.count) {
                        self.searchField.stringValue = url.host;
                        return;
                    }
                    else {

                    }
                    
                    NSString* domain = getPublicDomain(url.host);
                    [self smartInitializeSearchFromDomain:domain];
                }
                else {
                    NSString* domain = getPublicDomain(url.absoluteString);
                    [self smartInitializeSearchFromDomain:domain];
                }
            }
            else {

                NSString* domain = getPublicDomain(serviceId.identifier);
                [self smartInitializeSearchFromDomain:domain];
            }
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            [self smartInitializeSearchFromDomain:serviceId.identifier];
        }
    }
}

- (void)smartInitializeSearchFromDomain:(NSString*)domain {
    NSArray* items = [self getMatchingItems:domain scope:kSearchScopeAll];
    if(items.count) {
        self.searchField.stringValue = domain;
        return;
    }
    else {
        slog(@"No matches across all fields for Domain: %@", domain);
    }

    

    NSString * searchTerm = getCompanyOrOrganisationNameFromDomain(domain);
    
    self.searchField.stringValue = searchTerm;
    self.cautionImpreciseWarning.hidden = NO;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.doneSmartInit = YES;
    });
}

NSString *getPublicDomain(NSString* url) {
    if(url == nil) {
        return @"";
    }
    
    if(!url.length) {
        return @"";
    }

    return [BrowserAutoFillManager extractPSLDomainFromUrlWithUrl:url];
}

NSString *getCompanyOrOrganisationNameFromDomain(NSString* domain) {
    if(!domain.length) {
        return domain;
    }
    
    NSArray<NSString*> *parts = [domain componentsSeparatedByString:@"."];
    
    NSString *searchTerm = parts.count ? parts[0] : domain;
    return searchTerm;
}

- (NSArray<Node*>*)getMatchingItems:(NSString*)searchText scope:(SearchScope)scope {
    return [self.model search:searchText
                        scope:scope
                  dereference:YES
        includeKeePass1Backup:NO
            includeRecycleBin:NO
               includeExpired:NO
                includeGroups:NO
              browseSortField:kBrowseSortFieldTitle
                   descending:NO
            foldersSeparately:YES];
}



- (IBAction)onSelect:(id)sender {
    NSUInteger index = self.tableView.selectedRowIndexes.firstIndex;
    
    if (index != NSNotFound) {
        Node* node = [self getDataSource][index];
        
        NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
        NSString* user = [self.model dereference:node.fields.username node:node];
        if ( user.length == 0 ) {
            user = [self.model.database dereference:node.fields.email node:node]; 
        }
        
        NSString* password = [self.model dereference:node.fields.password node:node];

        [self dismissAndComplete:NO createNew:NO username:user password:password totp:totp];
    }
}

- (IBAction)onCancel:(id)sender {
    [self dismissAndComplete:YES createNew:NO username:nil password:nil totp:nil];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self bindSelectButton];
}

- (void)bindSelectButton {
    self.buttonSelect.enabled = self.tableView.selectedRowIndexes.firstIndex != NSNotFound;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self getDataSource].count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Node* node = [self getDataSource][row];

    NSString* title = [self dereference:node.title node:node];
    NSString* username = [self dereference:node.fields.username node:node];
    
    NSImage* icon = [NodeIconHelper getIconForNode:node predefinedIconSet:kKeePassIconSetClassic format:self.model.originalFormat large:NO];

    EntryTableCellView *result = [tableView makeViewWithIdentifier:kEntryTableCellViewIdentifier owner:self];

    NSString* path = [self.model.database getPathDisplayString:node];
    [result setContent:title username:username totp:node.fields.otpToken image:icon path:path database:self.model.metadata.nickName];
    
    return result;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.model dereference:text node:node];
}

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = theEvent.charactersIgnoringModifiers;
    unichar aChar = [chars characterAtIndex:0];
    
    BOOL cmd = ((theEvent.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
    
    if(cmd && (aChar == 'f' || aChar == 'F')) {
        [self.view.window makeFirstResponder:self.searchField];
    }
    else {

        [super keyDown:theEvent];
    }
}

- (IBAction)onCreateNew:(id)sender {
    [self dismissAndComplete:NO createNew:YES username:nil password:nil totp:nil];
}

- (void)dismissAndComplete:(BOOL)userCancelled createNew:(BOOL)createNew username:(NSString*_Nullable)username password:(NSString*_Nullable)password totp:(NSString*_Nullable)totp {
    if ( self.presentingViewController ) {
        [self.presentingViewController dismissViewController:self];
    }
    else if ( self.view.window.sheetParent ) {
        [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.view.window close];
    }
    
    self.onDone(userCancelled, createNew, username, password, totp);
}

@end
