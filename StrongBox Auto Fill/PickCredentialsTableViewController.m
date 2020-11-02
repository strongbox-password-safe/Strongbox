//
//  PickCredentialsTableViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PickCredentialsTableViewController.h"
#import "NodeIconHelper.h"
#import "NSArray+Extensions.h"
#import "Alerts.h"
#import "Utils.h"
#import "regdom.h"
#import "BrowseItemCell.h"
#import "ItemDetailsViewController.h"
#import "DatabaseSearchAndSorter.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "BrowseTableViewCellHelper.h"
#import "SharedAppAndAutoFillSettings.h"
#import "SafeStorageProviderFactory.h"
#import "AutoFillSettings.h"
#import "NSString+Extensions.h"
#import "UITableView+EmptyDataSet.h"

@interface PickCredentialsTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddCredential;
@property NSTimer* timerRefreshOtp;

//@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;
//@property (nonatomic) NSInteger tapCount;
//@property (nonatomic) NSIndexPath *tappedIndexPath;
//@property (strong, nonatomic) NSTimer *tapTimer;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonPreferences;

@property BrowseTableViewCellHelper* cellHelper;
@property BOOL doneFirstAppearanceTasks;

@end

@implementation PickCredentialsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(SharedAppAndAutoFillSettings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }

    if (@available(iOS 13.0, *)) { // Upgrade to fancy SF Symbols Preferences Icon if we can...
        [self.buttonPreferences setImage:[UIImage systemImageNamed:@"gear"]];
    }
    
    [self setupTableview];

    self.buttonAddCredential.enabled = [self canCreateNewCredential];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles =
        @[NSLocalizedString(@"pick_creds_vc_search_scope_title", @"Title"),
          NSLocalizedString(@"pick_creds_vc_search_scope_username", @"Username"),
          NSLocalizedString(@"pick_creds_vc_search_scope_password", @"Password"),
          NSLocalizedString(@"pick_creds_vc_search_scope_url", @"URL"),
          NSLocalizedString(@"browse_vc_search_scope_tags", @"Tags"),
          NSLocalizedString(@"pick_creds_vc_search_scope_all_fields", @"All")];
    
    self.searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        // We want the search bar visible all the time.
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        [self.searchController.searchBar sizeToFit];
    }
    
    [self loadItems];
}

- (void)setupTableview {
    self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.model tableView:self.tableView];
    
//    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
//                                initWithTarget:self
//                                action:@selector(handleLongPress:)];
//    self.longPressRecognizer.minimumPressDuration = 1;
//    self.longPressRecognizer.cancelsTouchesInView = YES;
    
//    [self.tableView addGestureRecognizer:self.longPressRecognizer];

    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.tableView.tableFooterView = [UIView new];
}

- (void)loadItems {
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.model];
    
    self.items = [searcher filterAndSortForBrowse:self.model.database.allRecords.mutableCopy
                            includeKeePass1Backup:self.model.metadata.showKeePass1BackupGroup
                                includeRecycleBin:self.model.metadata.showRecycleBinInSearchResults
                                   includeExpired:self.model.metadata.showExpiredInSearch
                                    includeGroups:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (IBAction)updateOtpCodes:(id)sender {
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:NO];
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
    
    if(!self.model.metadata.hideTotpInBrowse) {
        self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(updateOtpCodes:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Try to workaround Apple's disappearing keyboard problem...
    
    if (!self.doneFirstAppearanceTasks) {
        self.doneFirstAppearanceTasks = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self smartInitializeSearch];

            [self.searchController.searchBar becomeFirstResponder];

            // Auto Proceed...
            
            if (AutoFillSettings.sharedInstance.autoProceedOnSingleMatch) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSArray<Node *> *items = [self getDataSource];
                    if (self.searchController.isActive && items.count == 1) {
                        [self proceedWithItem:items.firstObject];
                    }
                });
            }
        });
    }
}

- (NSArray<Node *> *)getDataSource {
    return (self.searchController.isActive ? self.searchResults : self.items);
}

- (IBAction)onCancel:(id)sender {
    [self.rootViewController exitWithUserCancelled];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    
    [self filterContentForSearchText:searchString scope:(SearchScope)searchController.searchBar.selectedScopeButtonIndex];
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
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];
    
    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = serviceId.identifier.urlExtendedParse;
            
            //NSLog(@"URL: %@", url);
            
            // Direct URL Match?
            
            if (url) {
                NSArray* items = [self getMatchingItems:url.absoluteString scope:kSearchScopeUrl];
                if(items.count) {
                    [self.searchController.searchBar setText:url.absoluteString];
                    [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeUrl];
                    return;
                }
                else {
                    NSLog(@"No matches for URL: %@", url.absoluteString);
                }
                
                // Host URL Match?
                
                items = [self getMatchingItems:url.host scope:kSearchScopeUrl];
                if(items.count) {
                    [self.searchController.searchBar setText:url.host];
                    [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeUrl];
                    return;
                }
                else {
                    NSLog(@"No matches for URL: %@", url.host);
                }

                
                NSString* domain = getDomain(url.host);
                [self smartInitializeSearchFromDomain:domain];
            }
            else {
                NSLog(@"No matches for URL: %@", url);
            }
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            [self smartInitializeSearchFromDomain:serviceId.identifier];
        }
    }
}

- (void)smartInitializeSearchFromDomain:(NSString*)domain {
    // Domain URL Match?
    
    NSArray* items = [self getMatchingItems:domain scope:kSearchScopeUrl];
    if(items.count) {
        [self.searchController.searchBar setText:domain];
        [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeUrl];
        return;
    }
    else {
        NSLog(@"No matches in URLs for Domain: %@", domain);
    }
    
    // Broad Search across all fields for domain...
    
    items = [self getMatchingItems:domain scope:kSearchScopeAll];
    if(items.count) {
        [self.searchController.searchBar setText:domain];
        [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeAll];
        return;
    }
    else {
        NSLog(@"No matches across all fields for Domain: %@", domain);
    }

    // Broadest general search (try grab the company/organisation name from the host)
    
    NSString * searchTerm = getCompanyOrOrganisationNameFromDomain(domain);
    [self.searchController.searchBar setText:searchTerm];
    [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeAll];
}

- (NSArray<Node*>*)getMatchingItems:(NSString*)searchText scope:(SearchScope)scope {
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.model];
    
    return [searcher search:searchText
                      scope:scope
                dereference:self.model.metadata.searchDereferencedFields
      includeKeePass1Backup:self.model.metadata.showKeePass1BackupGroup
          includeRecycleBin:self.model.metadata.showRecycleBinInSearchResults
             includeExpired:self.model.metadata.showExpiredInSearch
              includeGroups:NO];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;  // Required for iOS 9 and 10
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    /* Return an estimated height or calculate
     * estimated height dynamically on information
     * that makes sense in your case.
     */
    return 60.0f; // Required for iOS 9 and 10
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger ret = [self getDataSource].count;
    __weak id weakSelf = self;
    if (ret == 0) {
        [self.tableView setEmptyTitle:[self getTitleForEmptyDataSet]
                          description:[self getDescriptionForEmptyDataSet]
                          buttonTitle:[self getButtonTitleForEmptyDataSet]
                         buttonAction:^{
            [weakSelf emptyDataSetDidTapButton];
        }];
    }
    else {
        [self.tableView setEmptyTitle:nil];
    }
    
    return ret;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node *node = [self getDataSource][indexPath.row];

    return [self.cellHelper getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:self.searchController.isActive];
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.model.database dereference:text node:node];
}

- (IBAction)onAddCredential:(id)sender {
    [self segueToCreateNew];
}

- (void)segueToCreateNew {
    [self performSegueWithIdentifier:@"segueToAddNew" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueToAddNew"]) {
        ItemDetailsViewController* vc = (ItemDetailsViewController*)segue.destinationViewController;
        [self addNewEntry:vc];
    }
    else if ([segue.identifier isEqualToString:@"segueToPreferences"]) { //     // Try to workaround Apple's disappearing keyboard problem...

        NSLog(@"segueToPreferences");
        [self.searchController.searchBar resignFirstResponder];
    }
    else {
        NSLog(@"Unknown SEGUE!");
    }
}

- (void)addNewEntry:(ItemDetailsViewController*)vc {
    NSString* suggestedTitle = nil;
    NSString* suggestedUrl = nil;
    NSString* suggestedNotes = nil;
    
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];

    if (AutoFillSettings.sharedInstance.storeAutoFillServiceIdentifiersInNotes) {
        suggestedNotes = [[serviceIdentifiers map:^id _Nonnull(ASCredentialServiceIdentifier * _Nonnull obj, NSUInteger idx) {
            return obj.identifier;
        }] componentsJoinedByString:@"\n\n"];
    }
    
    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = serviceId.identifier.urlExtendedParse;
            if(url && url.host.length) {
                NSString* bar = getDomain(url.host);
                NSString* foo = getCompanyOrOrganisationNameFromDomain(bar);
                suggestedTitle = foo.length ? [foo capitalizedString] : foo;
                
                if (AutoFillSettings.sharedInstance.useFullUrlAsURLSuggestion) {
                    suggestedUrl = url.absoluteString;
                }
                else {
                    suggestedUrl = [[url.scheme stringByAppendingString:@"://"] stringByAppendingString:url.host];
                }
            }
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            NSString* bar = getDomain(serviceId.identifier);
            NSString* foo = getCompanyOrOrganisationNameFromDomain(bar);
            suggestedTitle = foo.length ? [foo capitalizedString] : foo;
            suggestedUrl = serviceId.identifier;
        }
    }

    vc.createNewItem = YES;
    vc.item = nil;
    vc.parentGroup = self.model.database.rootGroup;
    vc.readOnly = NO;
    vc.databaseModel = self.model;
    vc.autoFillSuggestedUrl = suggestedUrl;
    vc.autoFillSuggestedTitle = suggestedTitle;
    vc.autoFillSuggestedNotes = suggestedNotes;
        
    vc.onAutoFillNewItemAdded = ^(NSString * _Nonnull username, NSString * _Nonnull password) {
        [self notifyUserToSwitchToAppAfterUpdate:username password:password];
    };
}

- (void)notifyUserToSwitchToAppAfterUpdate:(NSString*)username password:(NSString*)password {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.model.metadata.storageProvider != kLocalDevice && !AutoFillSettings.sharedInstance.dontNotifyToSwitchToMainAppForSync) {
            NSString* title = NSLocalizedString(@"autofill_add_entry_sync_required_title", @"Sync Required");
            NSString* locMessage = NSLocalizedString(@"autofill_add_entry_sync_required_message_fmt",@"You have added a new entry and this change has been saved locally.\n\nDon't forget to switch to the main Strongbox app to fully sync these changes to %@.");
            NSString* gotIt = NSLocalizedString(@"autofill_add_entry_sync_required_option_got_it",@"Got it!");
            NSString* gotItDontTellMeAgain = NSLocalizedString(@"autofill_add_entry_sync_required_option_dont_tell_again",@"Don't tell me again");
            
            NSString* storageName = [SafeStorageProviderFactory getStorageDisplayName:self.model.metadata];
            NSString* message = [NSString stringWithFormat:locMessage, storageName];
            
            [Alerts twoOptions:self title:title message:message defaultButtonText:gotIt secondButtonText:gotItDontTellMeAgain action:^(BOOL response) {
                if (response == NO) {
                    AutoFillSettings.sharedInstance.dontNotifyToSwitchToMainAppForSync = YES;
                }
                
                [self.rootViewController exitWithCredential:username password:password];
            }];
        }
        else {
            [self.rootViewController exitWithCredential:username password:password];
        }
    });
}
                
- (BOOL)canCreateNewCredential {
    return !self.model.isReadOnly;
}

- (void)emptyDataSetDidTapButton {
    if([self canCreateNewCredential]) {
        [self segueToCreateNew];
    }
    else {
        [Alerts info:self
               title:NSLocalizedString(@"pick_creds_vc_cannot_create_new_unsupported_storage_type_title", @"Unsupported Storage")
             message:NSLocalizedString(@"pick_creds_vc_cannot_create_new_unsupported_storage_type_message", @"This database is stored on a Storage Provider that does not support Live editing in App Extensions. Cannot Create New Record.")];
    }
}

- (NSAttributedString *)getButtonTitleForEmptyDataSet {
    NSDictionary *attributes = @{
                                 NSFontAttributeName : [UIFont systemFontOfSize:16.0f],
                                 NSForegroundColorAttributeName : UIColor.systemBlueColor
                                 };
    
    return [[NSAttributedString alloc] initWithString:NSLocalizedString(@"pick_creds_vc_create_new_button_title", @"Create New Record...")
                                           attributes:attributes];
}

- (NSAttributedString *)getTitleForEmptyDataSet
{
    NSString *text = self.searchController.isActive ?
        NSLocalizedString(@"pick_creds_vc_empty_search_dataset_title", @"No Matching Records") :
        NSLocalizedString(@"pick_creds_vc_empty_dataset_title", @"Empty Database");
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)getDescriptionForEmptyDataSet
{
    NSString *text = self.searchController.isActive ?
        NSLocalizedString(@"pick_creds_vc_empty_search_dataset_subtitle", @"Could not find any matching records") :
        NSLocalizedString(@"pick_creds_vc_empty_dataset_subtitle", @"It appears your database is empty");
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f],
                                 NSForegroundColorAttributeName: [UIColor lightGrayColor],
                                 NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

NSString *getDomain(NSString* host) {
    if(host == nil) {
        return @"";
    }
    
    if(!host.length) {
        return @"";
    }
    
    const char *cStringUrl = [host UTF8String];
    if(!cStringUrl || strlen(cStringUrl) == 0) {
        return @"";
    }
    
    void *tree = loadTldTree();
    const char *result = getRegisteredDomainDrop(cStringUrl, tree, 1);
    
    if(result == NULL) {
        return @"";
    }
    
    NSString *domain = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    
    NSLog(@"Calculated Domain: %@", domain);
    
    return domain;
}

NSString *getCompanyOrOrganisationNameFromDomain(NSString* domain) {
    if(!domain.length) {
        return domain;
    }
    
    NSArray<NSString*> *parts = [domain componentsSeparatedByString:@"."];
    
    NSLog(@"%@", parts);
    
    NSString *searchTerm =  parts.count ? parts[0] : domain;
    return searchTerm;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Long Press

//- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
//    if (sender.state != UIGestureRecognizerStateBegan) {
//        return;
//    }
//
//    CGPoint tapLocation = [self.longPressRecognizer locationInView:self.tableView];
//    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:tapLocation];
//
//    if (!indexPath || indexPath.row >= [self getDataSource].count) {
//        NSLog(@"Not on a cell");
//        return;
//    }
//
//    Node *item = [self getDataSource][indexPath.row];
//
//    if (item.isGroup) {
//        NSLog(@"Item is group, cannot Fast PW Copy...");
//        return;
//    }
//
//    NSLog(@"Fast Password Copy on %@", item.title);
//
//    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
//    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item]];
//}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray* arr = [self getDataSource];
    if(indexPath.row >= arr.count) {
        return;
    }
    Node *item = arr[indexPath.row];
    if(item) {
        [self proceedWithItem:item];
    }
    else {
        NSLog(@"WARN: DidSelectRow with no Record?!");
    }
//    if(self.tapCount == 1 && self.tapTimer != nil && [self.tappedIndexPath isEqual:indexPath]){
//        [self.tapTimer invalidate];
//
//        self.tapTimer = nil;
//        self.tapCount = 0;
//        self.tappedIndexPath = nil;
//
//        [self handleDoubleTap:indexPath];
//    }
//    else if(self.tapCount == 0){
//        //This is the first tap. If there is no tap till tapTimer is fired, it is a single tap
//        self.tapCount = self.tapCount + 1;
//        self.tappedIndexPath = indexPath;
//        self.tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
//    }
//    else if(![self.tappedIndexPath isEqual:indexPath]){
//        //tap on new row
//        self.tapCount = 0;
//        self.tappedIndexPath = indexPath;
//        if(self.tapTimer != nil){
//            [self.tapTimer invalidate];
//            self.tapTimer = nil;
//        }
//    }
}

//- (void)tapTimerFired:(NSTimer *)aTimer{
//    //timer fired, there was a single tap on indexPath.row = tappedRow
//    [self tapOnCell:self.tappedIndexPath];
//
//    self.tapCount = 0;
//    self.tappedIndexPath = nil;
//    self.tapTimer = nil;
//}
//
//- (void)tapOnCell:(NSIndexPath *)indexPath  {
//    NSArray* arr = [self getDataSource];
//    if(indexPath.row >= arr.count) {
//        return;
//    }
//    Node *item = arr[indexPath.row];
//    if(item) {
//        [self proceedWithItem:item];
//    }
//    else {
//        NSLog(@"WARN: DidSelectRow with no Record?!");
//    }
//}

//- (void)handleDoubleTap:(NSIndexPath *)indexPath {
//    NSArray* arr = [self getDataSource];
//    if(indexPath.row >= arr.count) {
//        return;
//    }
//    Node *item = arr[indexPath.row];
//
//    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.username node:item]];
//
//    NSLog(@"Fast Username Copy on %@", item.title);
//
//    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
//}

- (void)proceedWithItem:(Node*)item {
    if(item.fields.otpToken) {
        NSString* value = item.fields.otpToken.password;
        if (value.length) {
            [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
            NSLog(@"Copied TOTP to Pasteboard...");
        }
    }
    
    NSString* user = [self dereference:item.fields.username node:item];
    NSString* password = [self dereference:item.fields.password node:item];
    
    //NSLog(@"Return User/Pass from Node: [%@] - [%@] [%@]", user, password, record);
    
    [self.rootViewController exitWithCredential:user password:password];
}

@end
