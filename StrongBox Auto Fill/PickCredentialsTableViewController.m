//
//  PickCredentialsTableViewController.m
//  Strongbox AutoFill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "PickCredentialsTableViewController.h"
#import "NodeIconHelper.h"
#import "NSArray+Extensions.h"
#import "Alerts.h"
#import "Utils.h"
#import "ItemDetailsViewController.h"
#import "OTPToken+Generation.h"
#import "ClipboardManager.h"
#import "BrowseTableViewCellHelper.h"
#import "AppPreferences.h"
#import "SafeStorageProviderFactory.h"
#import "NSString+Extensions.h"
#import "AutoFillPreferencesViewController.h"
#import "PreviewItemViewController.h"
#import "ContextMenuHelper.h"
#import "LargeTextViewController.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

#import "SelectItemTableViewController.h"

static NSString* const kGroupTitleMatches = @"title";
static NSString* const kGroupUrlMatches = @"url";
static NSString* const kGroupAllFieldsMatches = @"all-matches";
static NSString* const kGroupNoMatchingItems = @"no-matches";
static NSString* const kGroupPinned = @"pinned";
static NSString* const kGroupServiceId = @"service-id";
static NSString* const kGroupActions = @"actions";
static NSString* const kGroupAllItems = @"all-items";

@interface PickCredentialsTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>

@property NSArray<NSString*> *groups;
@property (strong, nonatomic) NSDictionary<NSString*, NSArray<Node*>*> *groupedResults;

@property (strong, nonatomic) UISearchController *searchController;
@property NSTimer* timerRefreshOtp;

@property BrowseTableViewCellHelper* cellHelper;
@property BOOL doneFirstAppearanceTasks;
@property (readonly) BOOL foundSearchResults;
@property (readonly) BOOL showNoMatchesSection;
@property (readonly) BOOL showAllItemsSection;

@end

@implementation PickCredentialsTableViewController

+ (instancetype)fromStoryboard {
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"SelectExistingAutoFillCredential" bundle:nil];

    PickCredentialsTableViewController* vc = [mainStoryboard instantiateInitialViewController];
    
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(AppPreferences.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    
    [self setupTableview];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;

    self.navigationItem.searchController = self.searchController;
    
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    self.searchController.searchBar.enablesReturnKeyAutomatically = NO; 
        
    
    
    self.groups = @[
        kGroupNoMatchingItems,
        kGroupUrlMatches,
        kGroupTitleMatches,
        kGroupAllFieldsMatches,
        kGroupActions,
        kGroupPinned,
        kGroupServiceId,
        kGroupAllItems
    ];
    
    NSArray<Node*> *allItems = [self loadAllItems];
    NSArray<Node*> *pinnedItems = [self loadPinnedItems];
    
    self.groupedResults = @{ kGroupAllItems : allItems,
                             kGroupPinned : pinnedItems };
}

- (void)setupTableview {
    self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.model tableView:self.tableView];
    
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.tableView.tableFooterView = [UIView new];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if(self.timerRefreshOtp) {
        [self.timerRefreshOtp invalidate];
        self.timerRefreshOtp = nil;
    }
}

- (void)updateOtpCodes:(id)sender {
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
    
    self.timerRefreshOtp = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(updateOtpCodes:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timerRefreshOtp forMode:NSRunLoopCommonModes];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    
    
    if (!self.doneFirstAppearanceTasks) {
        self.doneFirstAppearanceTasks = YES;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25  * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
            [self smartInitializeSearch];

            [self.searchController.searchBar becomeFirstResponder];

            
            
            if ( AppPreferences.sharedInstance.autoProceedOnSingleMatch && !self.twoFactorOnly ) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self proceedWithSingleMatch];
                });
            }
        });
    }
}

- (NSUInteger)getSearchResultsCount {
    NSArray<Node*>* urls = self.groupedResults[kGroupUrlMatches];
    NSArray<Node*>* titles = self.groupedResults[kGroupTitleMatches];
    NSArray<Node*>* others = self.groupedResults[kGroupAllFieldsMatches];

    NSUInteger urlCount = urls ? urls.count : 0;
    NSUInteger titleCount = titles ? titles.count : 0;
    NSUInteger otherCount = others ? others.count : 0;

    return urlCount + titleCount + otherCount;
}

- (IBAction)onCancel:(id)sender {
    self.completion(YES, nil, nil, nil);
}

- (void)smartInitializeSearch {
    ASCredentialServiceIdentifier *serviceId = self.serviceIdentifiers.firstObject;
    
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = serviceId.identifier.urlExtendedParse;
            
            
            
            
            
            if (url) {
                NSArray* items = [self getMatchingItems:url.absoluteString scope:kSearchScopeUrl];
                if(items.count) {
                    [self.searchController.searchBar setText:url.absoluteString];
                    return;
                }
                else {

                }
                
                
                
                if ( url.host.length ) { 
                    items = [self getMatchingItems:url.host scope:kSearchScopeUrl];
                    if(items.count) {
                        [self.searchController.searchBar setText:url.host];
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
    if(!domain.length) {
        return;
    }
    
    if ( [domain hasPrefix:@"www."] && domain.length > 4) {
        domain = [domain substringFromIndex:4];
    }
    
    
    
    NSArray* items = [self getMatchingItems:domain scope:kSearchScopeUrl];
    if(items.count) {
        [self.searchController.searchBar setText:domain];

        return;
    }
    else {
        slog(@"No matches in URLs for Domain: %@", domain);
    }
    
    
    
    items = [self getMatchingItems:domain scope:kSearchScopeAll];
    if(items.count) {
        [self.searchController.searchBar setText:domain];

        return;
    }
    else {
        slog(@"No matches across all fields for Domain: %@", domain);
    }

    
    
    NSString * searchTerm = getCompanyOrOrganisationNameFromDomain(domain);
    [self.searchController.searchBar setText:searchTerm];

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

static NSString *getCompanyOrOrganisationNameFromDomain(NSString* domain) {
    if(!domain.length) {
        return domain;
    }
    
    NSArray<NSString*> *parts = [domain componentsSeparatedByString:@"."];
    
    NSString *searchTerm = parts.count ? parts[0] : domain;
    return searchTerm;
}

- (NSArray<Node*>*)loadAllItems {
    NSArray<Node*>* entries = self.twoFactorOnly ? self.model.totpEntries : self.model.allSearchableNoneExpiredEntries;
    
    return [self.model filterAndSortForBrowse:entries.mutableCopy includeGroups:NO];
}

- (NSArray<Node*>*)loadPinnedItems {
    if( !self.model.favourites.count || !AppPreferences.sharedInstance.autoFillShowFavourites || self.twoFactorOnly ) {
        return @[];
    }
    
    BrowseSortConfiguration* sortConfig = [self.model getDefaultSortConfiguration];
    
    return [self.model filterAndSortForBrowse:self.model.favourites.mutableCopy
                        includeKeePass1Backup:NO
                            includeRecycleBin:NO
                               includeExpired:YES
                                includeGroups:NO
                              browseSortField:sortConfig.field
                                   descending:sortConfig.descending
                            foldersSeparately:sortConfig.foldersOnTop];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *searchString = searchController.searchBar.text;
    
    NSMutableDictionary* updated = self.groupedResults.mutableCopy;

    if(!searchString.length) {
        updated[kGroupUrlMatches] = @[];
        updated[kGroupTitleMatches] =  @[];
        updated[kGroupAllFieldsMatches] = @[];
    }
    else {
        NSArray<Node*> *urlMatches = [self getMatchingItems:searchString scope:kSearchScopeUrl];
        NSArray<Node*> *titleMatches = [self getMatchingItems:searchString scope:kSearchScopeTitle];
        NSArray<Node*> *otherFieldMatches = [self getMatchingItems:searchString scope:kSearchScopeAll];
        
        updated[kGroupUrlMatches] = urlMatches;
        NSSet<NSUUID*>* urlMatchSet = [urlMatches map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }].set;
        
        titleMatches = [titleMatches filter:^BOOL(Node * _Nonnull obj) {
            return ![urlMatchSet containsObject:obj.uuid];
        }];
        
        updated[kGroupTitleMatches] = titleMatches;
        
        NSSet<NSUUID*>* titleMatchSet = [titleMatches map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
            return obj.uuid;
        }].set;

        otherFieldMatches = [otherFieldMatches filter:^BOOL(Node * _Nonnull obj) {
            return ![urlMatchSet containsObject:obj.uuid] && ![titleMatchSet containsObject:obj.uuid];
        }];
        
        updated[kGroupAllFieldsMatches] = otherFieldMatches;
    }
    
    self.groupedResults = updated;
    
    [self.tableView reloadData];
}

- (NSArray<Node*>*)getMatchingItems:(NSString*)searchText scope:(SearchScope)scope {
    NSArray<Node*>* ret = [self.model search:searchText scope:scope includeGroups:NO];
    
    if ( self.twoFactorOnly ) {
        return [ret filter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.otpToken != nil;
        }];
    }
    else {
        return ret;
    }
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.groups.count;
}

- (BOOL)foundSearchResults {
    return [self getSearchResultsCount] != 0;
}

- (BOOL)showNoMatchesSection {
    return !self.foundSearchResults && self.searchController.searchBar.text.length != 0;
}

- (BOOL)showAllItemsSection {
    return !self.foundSearchResults || self.searchController.searchBar.text.length == 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString* group = self.groups[section];
    
    if ( [group isEqualToString:kGroupServiceId] ) {
        return 1;
    }
    else if ( [group isEqualToString:kGroupActions] ) {
        return 2;
    }
    else if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        return self.showNoMatchesSection ? 1 : 0;
    }
    else if ( [group isEqualToString:kGroupAllItems] ) {
        NSArray<Node*> *items = self.groupedResults[kGroupAllItems];
        return self.showAllItemsSection ? (items ? items.count : 0) : 0;
    }
    else {
        NSArray<Node*> *items = self.groupedResults[group];
        return items ? items.count : 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* group = self.groups[indexPath.section];
    
    if ( [group isEqualToString:kGroupServiceId] ) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"PickCredentialGenericCell" forIndexPath:indexPath];
      

        cell.textLabel.text = @"";
        cell.detailTextLabel.text = self.serviceIdentifiers.firstObject ? self.serviceIdentifiers.firstObject.identifier : NSLocalizedString(@"generic_none", @"None");
        
        cell.imageView.image = nil;
        
        return cell;
    }
    else if ( [group isEqualToString:kGroupActions] ) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"PickCredentialGenericBasicCell" forIndexPath:indexPath];
        
        if ( indexPath.row == 0 ) {
            cell.textLabel.text = NSLocalizedString(@"pick_creds_vc_create_new_button_title", @"Create New Entry...");
            cell.imageView.image = [UIImage systemImageNamed:@"plus"];
            cell.imageView.tintColor = [self canCreateNewCredential] ? nil : UIColor.secondaryLabelColor;
            
            cell.textLabel.textColor = [self canCreateNewCredential] ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;

            cell.userInteractionEnabled = [self canCreateNewCredential];
        }
        else {
            cell.textLabel.text = NSLocalizedString(@"generic_settings", @"Settings");
            cell.imageView.image = [UIImage systemImageNamed:@"gear"];
            
            cell.textLabel.textColor = UIColor.systemBlueColor;
            cell.userInteractionEnabled = YES;
        }
        
        return cell;
    }
    else if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:@"PickCredentialGenericBasicCell" forIndexPath:indexPath];
        
        cell.textLabel.text = NSLocalizedString(@"pick_creds_vc_empty_search_dataset_title", @"No Matching Records");
        cell.imageView.image = [UIImage imageNamed:@"search"];
        cell.textLabel.textColor = UIColor.labelColor;
        
        return cell;
    }
    else {
        NSArray<Node*> *items = self.groupedResults[group];
        Node* item = (items && items.count > indexPath.row) ? items[indexPath.row] : nil;

        if ( item ) {
            return [self.cellHelper getBrowseCellForNode:item indexPath:indexPath showLargeTotpCell:NO showGroupLocation:self.searchController.isActive];
        }
        else { 
            return [self.tableView dequeueReusableCellWithIdentifier:@"PickCredentialGenericCell" forIndexPath:indexPath];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString* group = self.groups[indexPath.section];
    
    if ( [group isEqualToString:kGroupServiceId] ) {
        if ( self.serviceIdentifiers.firstObject ) {
            [ClipboardManager.sharedInstance copyStringWithNoExpiration:self.serviceIdentifiers.firstObject.identifier];
        }
    }
    else if ( [group isEqualToString:kGroupActions] ) {
        if ( indexPath.row == 0 ) {
            [self onAddCredential:nil];
        }
        else {
            [self onPreferences:nil];
        }
    }
    else if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        
    }
    else {
        NSArray<Node*> *items = self.groupedResults[group];
        Node* item = (items && items.count > indexPath.row) ? items[indexPath.row] : nil;

        if(item) {
            [self proceedWithItem:item];
        }
        else {
            slog(@"WARN: DidSelectRow with no Record?!");
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSString* group = self.groups[section];

    if ( [group isEqualToString:kGroupTitleMatches] ) {
        return NSLocalizedString(@"autofill_search_title_matches_section_header", @"Title Matches");
    }
    else if ( [group isEqualToString:kGroupUrlMatches] ) {
        return NSLocalizedString(@"autofill_search_url_matches_section_header", @"URL Matches");
    }
    else if ( [group isEqualToString:kGroupAllFieldsMatches] ) {
        return NSLocalizedString(@"autofill_search_other_matches_section_header", @"Other Matches");
    }
    else if ( [group isEqualToString:kGroupPinned] ) {
        return NSLocalizedString(@"browse_vc_section_title_pinned", @"Pinned");
    }
    else if ( [group isEqualToString:kGroupServiceId] ) {
        return NSLocalizedString(@"autofill_search_title_service_id_section_header", @"Service ID");
    }
    else if ( [group isEqualToString:kGroupActions] ) {
        return NSLocalizedString(@"generic_actions", @"Actions");
    }
    else if ( [group isEqualToString:kGroupAllItems] ) {
        return self.twoFactorOnly ? NSLocalizedString(@"quick_view_title_totp_entries_title", @"2FA Codes") : NSLocalizedString(@"quick_view_title_all_entries_title", @"All Entries");
    }
    else if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        return NSLocalizedString(@"quick_view_title_no_matches_title", @"Results");
    }
    
    return self.groups[section];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString* group = self.groups[section];

    if ( [group isEqualToString:kGroupServiceId] ) {
        return self.serviceIdentifiers.count > 0 ? NSLocalizedString(@"autofill_search_service_id_section_footer", @"") : nil;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString* group = self.groups[section];
    
    if ( [group isEqualToString:kGroupActions] ) {
        return (self.twoFactorOnly || self.alsoRequestFieldSelection) ? 0.1f : UITableViewAutomaticDimension;
    }

    if ( [group isEqualToString:kGroupServiceId] ) {
        return self.serviceIdentifiers.count > 0 ? UITableViewAutomaticDimension : 0.1f;
    }
    
    if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        return self.showNoMatchesSection ? UITableViewAutomaticDimension : 0.1f;
    }
    
    if ( [group isEqualToString:kGroupAllItems] ) {
        return self.showAllItemsSection ? UITableViewAutomaticDimension : 0.1f;
    }
    
    if ( ![group isEqualToString:kGroupServiceId] && ![group isEqualToString:kGroupActions] ) {
        NSArray<Node*> *items = self.groupedResults[group];
        if ( items.count == 0) {
            return 0.1f;
        }
    }

    
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* group = self.groups[indexPath.section];

    if ( [group isEqualToString:kGroupActions] ) {
        if ( indexPath.row == 0 ) {
            if ( self.model.isReadOnly || self.twoFactorOnly || self.alsoRequestFieldSelection ) {
                return 0.0f;
            }
        }
        else {
            if ( self.twoFactorOnly || self.alsoRequestFieldSelection ) {
                return 0.0f;
            }
        }
    }

    if ( [group isEqualToString:kGroupServiceId] ) {
        if ( self.serviceIdentifiers.count == 0 ) {
            return 0.0f;
        }
    }




    
    return [super tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    NSString* group = self.groups[section];





        if ( [group isEqualToString:kGroupServiceId] ) {
            return self.serviceIdentifiers.count > 0 ? UITableViewAutomaticDimension : 0.1f;
        }

        return 0.1f;

}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString* group = self.groups[section];

    if ( [group isEqualToString:kGroupNoMatchingItems] ) {
        return self.showNoMatchesSection ? [super tableView:tableView viewForHeaderInSection:section] : [self sectionFiller];
    }

    if ( [group isEqualToString:kGroupAllItems] ) {
        return self.showAllItemsSection ? [super tableView:tableView viewForHeaderInSection:section] : [self sectionFiller];
    }

    if ( [group isEqualToString:kGroupServiceId] ) {
        return self.serviceIdentifiers.count > 0 ? [super tableView:tableView viewForHeaderInSection:section] : [self sectionFiller];
    }

    if ( [group isEqualToString:kGroupActions] ) {
        return (self.twoFactorOnly || self.alsoRequestFieldSelection) ? [self sectionFiller] : [super tableView:tableView viewForHeaderInSection:section];
    }
    
    if ( ![group isEqualToString:kGroupServiceId]  && ![group isEqualToString:kGroupActions] ) {
        NSArray<Node*> *items = self.groupedResults[group];
        if ( items.count == 0) {
            return [self sectionFiller];
        }
    }

    return [super tableView:tableView viewForHeaderInSection:section];
}

- (UIView *)sectionFiller {
    static UILabel *emptyLabel = nil;
    if (!emptyLabel) {
        emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        emptyLabel.backgroundColor = [UIColor clearColor];
    }
    return emptyLabel;
}

- (Node*)getTopMatch {
    NSArray<Node*>* urls = self.groupedResults[kGroupUrlMatches];
    NSArray<Node*>* titles = self.groupedResults[kGroupTitleMatches];
    NSArray<Node*>* others = self.groupedResults[kGroupAllFieldsMatches];

    NSUInteger urlCount = urls ? urls.count : 0;
    NSUInteger titleCount = titles ? titles.count : 0;
    NSUInteger otherCount = others ? others.count : 0;

    if ( ( urlCount + titleCount + otherCount ) > 0 ) {
        if ( urlCount ) {
            return urls.firstObject;
        }
        else if ( titleCount ) {
            return titles.firstObject;
        }
        
        return others.firstObject;
    }
    
    return nil;
}

- (void)proceedWithSingleMatch {
    if ( [self getSearchResultsCount] == 1 ) {
        [self proceedWithTopMatch];
    }
}

- (void)proceedWithTopMatch {
    Node* item = [self getTopMatch];
    
    if ( item ) {
        [self proceedWithItem:item];
    }
}

- (void)proceedWithItem:(Node*)item {
    if ( self.alsoRequestFieldSelection ) {
        [self promptForFieldSelection:item];
    }
    else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
            self.completion(NO, item, nil, nil);
        }];
    }
}



- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if ( self.foundSearchResults ) {
        [self proceedWithTopMatch];
    }
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    return [self.model.database dereference:text node:node];
}

- (IBAction)onAddCredential:(id)sender {
    if ( [self canCreateNewCredential] ) {
        [self performSegueWithIdentifier:@"segueToAddNew" sender:nil];
    }
}

- (IBAction)onPreferences:(id)sender {
    [self performSegueWithIdentifier:@"segueToPreferences" sender:self.model];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {  
    if ([segue.identifier isEqualToString:@"segueToAddNew"]) {
        ItemDetailsViewController* vc = (ItemDetailsViewController*)segue.destinationViewController;
        [self addNewEntry:vc];
    }
    else if ([segue.identifier isEqualToString:@"segueToPreferences"]) {
        
        
        
        slog(@"segueToPreferences");
        [self.searchController.searchBar resignFirstResponder];
        
        UINavigationController* nav = segue.destinationViewController;
        AutoFillPreferencesViewController* vc = (AutoFillPreferencesViewController*)nav.topViewController;
        vc.viewModel = sender;
    }
    else {
        slog(@"Unknown SEGUE!");
    }
}

- (void)addNewEntry:(ItemDetailsViewController*)vc {
    NSString* suggestedTitle = nil;
    NSString* suggestedUrl = nil;
    NSString* suggestedNotes = nil;
    
    if (AppPreferences.sharedInstance.storeAutoFillServiceIdentifiersInNotes) {
        suggestedNotes = [[self.serviceIdentifiers map:^id _Nonnull(ASCredentialServiceIdentifier * _Nonnull obj, NSUInteger idx) {
            return obj.identifier;
        }] componentsJoinedByString:@"\n\n"];
    }
    
    ASCredentialServiceIdentifier *serviceId = [self.serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = serviceId.identifier.urlExtendedParse;
            if(url && url.host.length) {
                NSString* bar = getPublicDomain(url.host);
                NSString* foo = getCompanyOrOrganisationNameFromDomain(bar);
                suggestedTitle = foo.length ? [foo capitalizedString] : foo;
                
                if (AppPreferences.sharedInstance.useFullUrlAsURLSuggestion) {
                    suggestedUrl = url.absoluteString;
                }
                else {
                    suggestedUrl = [[url.scheme stringByAppendingString:@":
                }
            }
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            NSString* bar = getPublicDomain(serviceId.identifier);
            NSString* foo = getCompanyOrOrganisationNameFromDomain(bar);
            suggestedTitle = foo.length ? [foo capitalizedString] : foo;
            suggestedUrl = serviceId.identifier;
        }
    }

    vc.createNewItem = YES;
    vc.itemId = nil;
    vc.parentGroupId = self.model.database.effectiveRootGroup.uuid;
    vc.forcedReadOnly = NO;
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
        if (self.model.metadata.storageProvider != kLocalDevice && !AppPreferences.sharedInstance.dontNotifyToSwitchToMainAppForSync) {
            NSString* title = NSLocalizedString(@"autofill_add_entry_sync_required_title", @"Sync Required");
            NSString* locMessage = NSLocalizedString(@"autofill_add_entry_sync_required_message_fmt",@"You have added a new entry and this change has been saved locally.\n\nDon't forget to switch to the main Strongbox app to fully sync these changes to %@.");
            NSString* gotIt = NSLocalizedString(@"autofill_add_entry_sync_required_option_got_it",@"Got it!");
            NSString* gotItDontTellMeAgain = NSLocalizedString(@"autofill_add_entry_sync_required_option_dont_tell_again",@"Don't tell me again");
            
            NSString* storageName = [SafeStorageProviderFactory getStorageDisplayName:self.model.metadata];
            NSString* message = [NSString stringWithFormat:locMessage, storageName];
            
            [Alerts twoOptions:self title:title message:message defaultButtonText:gotIt secondButtonText:gotItDontTellMeAgain action:^(BOOL response) {
                if (response == NO) {
                    AppPreferences.sharedInstance.dontNotifyToSwitchToMainAppForSync = YES;
                }
                
                self.completion(NO, nil, username, password);
            }];
        }
        else {
            self.completion(NO, nil, username, password);
        }
    });
}

- (BOOL)canCreateNewCredential {
    return !self.model.isReadOnly && !self.disableCreateNew;
}



- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if ( !AppPreferences.sharedInstance.autoFillLongTapPreview ) {
        return nil;
    }
    
    NSString* group = self.groups[indexPath.section];
    if ( [group isEqualToString:kGroupServiceId] || [group isEqualToString:kGroupActions] || [group isEqualToString:kGroupNoMatchingItems] ) {
        return nil;
    }
    NSArray<Node*> *items = self.groupedResults[group];
    Node* item = (items && items.count > indexPath.row) ? items[indexPath.row] : nil;
    if (!item) {
        return nil;
    }

    __weak PickCredentialsTableViewController* weakSelf = self;
    
    return [UIContextMenuConfiguration configurationWithIdentifier:indexPath
                                                   previewProvider:^UIViewController * _Nullable{ return item.isGroup ? nil : [PreviewItemViewController forItem:item andModel:self.model];   }
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        return [UIMenu menuWithTitle:@""
                               image:nil
                          identifier:nil
                             options:kNilOptions
                            children:@[
                                [weakSelf getContextualMenuNonMutators:indexPath item:item],
                                [weakSelf getContextualMenuCopyToClipboard:indexPath item:item],
                                [weakSelf getContextualMenuCopyFieldToClipboard:indexPath item:item],

                            ]];
    }];
}

- (UIMenu*)getContextualMenuCopyToClipboard:(NSIndexPath*)indexPath item:(Node*)item {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    
    
    if ( !item.isGroup && item.fields.username.length ) [ma addObject:[self getContextualMenuCopyUsernameAction:indexPath item:item]];

    

    if ( !item.isGroup && item.fields.password.length ) [ma addObject:[self getContextualMenuCopyPasswordAction:indexPath item:item]];

    

    if ( !item.isGroup && item.fields.otpToken ) [ma addObject:[self getContextualMenuCopyTotpAction:indexPath item:item]];

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuCopyUsernameAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak PickCredentialsTableViewController* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_username", @"Copy Username")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyUsername:item];
    }];
}

- (UIAction*)getContextualMenuCopyPasswordAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak PickCredentialsTableViewController* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_password", @"Copy Password")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyPassword:item];
    }];
}

- (UIAction*)getContextualMenuCopyTotpAction:(NSIndexPath*)indexPath item:(Node*)item  {
    __weak PickCredentialsTableViewController* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_prefs_tap_action_copy_copy_totp", @"Copy TOTP")
                           systemImage:@"doc.on.doc"
                               handler:^(__kindof UIAction * _Nonnull action) {
        [weakSelf copyTotp:item];
    }];
}

- (UIMenu*)getContextualMenuNonMutators:(NSIndexPath*)indexPath item:(Node*)item  {
    NSMutableArray<UIAction*>* ma = [NSMutableArray array];
        
    if (item.fields.password.length) [ma addObject:[self getContextualMenuShowLargePasswordAction:indexPath item:item]];
        
    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (UIAction*)getContextualMenuShowLargePasswordAction:(NSIndexPath*)indexPath item:(Node*)item {
    __weak PickCredentialsTableViewController* weakSelf = self;
    
    return [ContextMenuHelper getItem:NSLocalizedString(@"browse_context_menu_show_password", @"Show Password")
                           systemImage:@"eye"
                               handler:^(__kindof UIAction * _Nonnull action) {
        NSString* pw = [weakSelf dereference:item.fields.password node:item];
        [self showLargeTextView:pw];
    }];
}

- (void)showLargeTextView:(NSString*)password {
    LargeTextViewController* vc = [LargeTextViewController fromStoryboard];
    vc.string = password;
    vc.colorize = self.model.metadata.colorizePasswords;
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (UIMenu*)getContextualMenuCopyFieldToClipboard:(NSIndexPath*)indexPath item:(Node*)item {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    
    if ( !item.isGroup ) [ma addObject:[self getContextualMenuCopyToClipboardSubmenu:indexPath item:item]];

    return [UIMenu menuWithTitle:NSLocalizedString(@"browse_context_menu_copy_other_field", @"Copy Other Field...")
                           image:nil
                      identifier:nil
                         options:kNilOptions
                        children:ma];
}

- (UIMenuElement*)getContextualMenuCopyToClipboardSubmenu:(NSIndexPath*)indexPath item:(Node*)item {
    NSMutableArray<UIMenuElement*>* ma = [NSMutableArray array];
    __weak PickCredentialsTableViewController* weakSelf = self;
    
    if ( !item.isGroup ) {
        

        if ( item.fields.email.length ) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_email" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyEmail:item];
            }]];
        }
        
        

        if (item.fields.notes.length) {
            [ma addObject:[self getContextualMenuGenericCopy:@"generic_fieldname_notes" item:item handler:^(__kindof UIAction * _Nonnull action) {
                [weakSelf copyNotes:item];
            }]];
        }

        
        
        NSMutableArray* customFields = [NSMutableArray array];
        NSArray* sortedKeys = [item.fields.customFieldsNoEmail.allKeys sortedArrayUsingComparator:finderStringComparator];
        for(NSString* key in sortedKeys) {
            if ( ![NodeFields isTotpCustomFieldKey:key] ) {
                [customFields addObject:[self getContextualMenuGenericCopy:key item:item handler:^(__kindof UIAction * _Nonnull action) {
                    StringValue* sv = item.fields.customFields[key];
                    
                    NSString* value = [weakSelf dereference:sv.value node:item];
                    
                    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:value];
                }]];
            }
        }
        
        if (customFields.count) {
            [ma addObject:[UIMenu menuWithTitle:@""
                                          image:nil
                                     identifier:nil
                                        options:UIMenuOptionsDisplayInline
                                       children:customFields]];
        }
    }

    return [UIMenu menuWithTitle:@""
                           image:nil
                      identifier:nil
                         options:UIMenuOptionsDisplayInline
                        children:ma];
}

- (void)copyEmail:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.email node:item]];
}

- (void)copyNotes:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.notes node:item]];
}

- (void)copyUsername:(Node*)item {
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:[self dereference:item.fields.username node:item]];
}

- (void)copyTotp:(Node*)item {
    if(!item.fields.otpToken) {
        return;
    }
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:item.fields.otpToken.password];
}

- (void)copyPassword:(Node *)item {
    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
    
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item]];
}

- (void)copyAllFields:(Node*)item {
    NSMutableArray<NSString*>* fields = NSMutableArray.array;
    
    [fields addObject:[self dereference:item.title node:item]];
    [fields addObject:[self dereference:item.fields.username node:item]];
    [fields addObject:[self dereference:item.fields.password node:item]];
    [fields addObject:[self dereference:item.fields.url node:item]];
    [fields addObject:[self dereference:item.fields.notes node:item]];
    [fields addObject:[self dereference:item.fields.email node:item]];
    
    
    
    NSArray* sortedKeys = [item.fields.customFields.allKeys sortedArrayUsingComparator:finderStringComparator];
    for(NSString* key in sortedKeys) {
        if ( ![NodeFields isTotpCustomFieldKey:key] ) {
            StringValue* sv = item.fields.customFields[key];
            NSString *val = [self dereference:sv.value node:item];
            [fields addObject:val];
        }
    }

    
    
    NSArray<NSString*> *all = [fields filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length != 0;
    }];
    
    NSString* allString = [all componentsJoinedByString:@"\n"];
    [ClipboardManager.sharedInstance copyStringWithDefaultExpiration:allString];
}

- (UIAction*)getContextualMenuGenericCopy:(NSString*)locKey item:(Node*)item handler:(UIActionHandler)handler  {
    return [ContextMenuHelper getItem:NSLocalizedString(locKey, nil) systemImage:@"doc.on.doc" handler:handler];
}



- (void)promptForFieldSelection:(Node*)item  {
    NSMutableArray<NSString*>* fields = NSMutableArray.array;
    NSMutableArray<NSString*>* values = NSMutableArray.array;
    
    if ( item.fields.username.length ) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_username", @"Username")];
        [values addObject:[self dereference:item.fields.username node:item]];
    }
    
    if ( item.fields.password.length ) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_password", @"Password")];
        [values addObject:[self dereference:item.fields.password node:item]];
    }
    
    if ( item.fields.otpToken ) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_totp", @"2FA Code")];
        [values addObject:item.fields.otpToken.password];
    }
    
    if ( item.fields.email.length ) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_email", @"Email")];
        [values addObject:[self dereference:item.fields.email node:item]];
    }
    
    if ( item.fields.url.length ) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_url", @"URL")];
        [values addObject:[self dereference:item.fields.url node:item]];
    }
    
    if (item.fields.notes.length) {
        [fields addObject:NSLocalizedString(@"generic_fieldname_notes", @"Notes")];
        [values addObject:[self dereference:item.fields.notes node:item]];
    }
    
    
    
    NSArray<NSString*> *allKeys = item.fields.customFieldsNoEmail.allKeys;
    NSArray* sortedKeys = self.model.metadata.customSortOrderForFields ? allKeys : [allKeys sortedArrayUsingComparator:finderStringComparator];
    
    for(NSString* key in sortedKeys) {
        if (![NodeFields isTotpCustomFieldKey:key] &&
            ![NodeFields isPasskeyCustomFieldKey:key] ) {
            StringValue* sv = item.fields.customFields[key];
            NSString* value = [self dereference:sv.value node:item];
            
            [fields addObject:key];
            [values addObject:value];
        }
    }
    
    
    
    __weak PickCredentialsTableViewController* weakSelf = self;
    [self promptForChoice:NSLocalizedString(@"select_field_to_insert_text", @"Select Field to Insert Text")
                  options:fields
     currentlySelectIndex:NSNotFound
               completion:^(BOOL success, NSInteger selectedIndex) {
        if ( !success ) {
            return;
        }
        
        NSString* text = values[selectedIndex];
        
        [weakSelf.presentingViewController dismissViewControllerAnimated:YES completion:^{
            weakSelf.completion(NO, item, nil, text);
        }];
    }];
}

- (void)promptForChoice:(NSString*)title
                options:(NSArray<NSString*>*)items
   currentlySelectIndex:(NSInteger)currentlySelectIndex
             completion:(void(^)(BOOL success, NSInteger selectedIndex))completion {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"SelectItem" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    SelectItemTableViewController *vc = (SelectItemTableViewController*)nav.topViewController;
    vc.groupItems = @[items];
    
    if ( currentlySelectIndex != NSNotFound ) {
        vc.selectedIndexPaths = @[[NSIndexSet indexSetWithIndex:currentlySelectIndex]];
    }
    else {
        vc.selectedIndexPaths = nil;
    }
    
    vc.onSelectionChange = ^(NSArray<NSIndexSet *> * _Nonnull selectedIndices) {
        NSIndexSet* set = selectedIndices.firstObject;
        [self.navigationController popViewControllerAnimated:YES];
        completion(YES, set.firstIndex);
    };
    
    vc.title = title;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
