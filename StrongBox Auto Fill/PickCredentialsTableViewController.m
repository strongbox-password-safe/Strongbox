//
//  PickCredentialsTableViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PickCredentialsTableViewController.h"
#import "NodeIconHelper.h"
#import "Settings.h"
#import "NSArray+Extensions.h"
//#import "OTPToken+Generation.h"
#import "Alerts.h"
#import "Utils.h"
#import "regdom.h"
#import "BrowseItemCell.h"
#import "ItemDetailsViewController.h"
#import "DatabaseSearchAndSorter.h"
#import "OTPToken+Generation.h"

static NSString* const kBrowseItemCell = @"BrowseItemCell";

@interface PickCredentialsTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddCredential;
@property NSTimer* timerRefreshOtp;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;
@property (nonatomic) NSInteger tapCount;
@property (nonatomic) NSIndexPath *tappedIndexPath;
@property (strong, nonatomic) NSTimer *tapTimer;

@end

@implementation PickCredentialsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(Settings.sharedInstance.hideTips) {
        self.navigationItem.prompt = nil;
    }
    
    [self.tableView registerNib:[UINib nibWithNibName:kBrowseItemCell bundle:nil] forCellReuseIdentifier:kBrowseItemCell];
    
    self.longPressRecognizer = [[UILongPressGestureRecognizer alloc]
                                initWithTarget:self
                                action:@selector(handleLongPress:)];
    self.longPressRecognizer.minimumPressDuration = 1;
    self.longPressRecognizer.cancelsTouchesInView = YES;
    
    [self.tableView addGestureRecognizer:self.longPressRecognizer];
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.estimatedRowHeight = UITableViewAutomaticDimension;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.tableView.tableFooterView = [UIView new];
    
    self.buttonAddCredential.enabled = [self canCreateNewCredential];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles = @[@"Title", @"Username", @"Password", @"URL", @"All Fields"];
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

- (void)loadItems {
    self.items = self.model.database.allRecords;
    
    // Filter KeePass1 Backup Group if so configured...
    
    if(!self.model.metadata.showKeePass1BackupGroup) {
        if (self.model.database.format == kKeePass1) {
            Node* backupGroup = self.model.database.keePass1BackupNode;
            
            if(backupGroup) {
                self.items = [self.model.database.allRecords filter:^BOOL(Node * _Nonnull obj) {
                    return ![backupGroup contains:obj];
                }];
            }
        }
    }
    
    // Filter Recycle Bin...
    
    Node* recycleBin = self.model.database.recycleBinNode;
    if(recycleBin) {
        self.items = [self.items filter:^BOOL(Node * _Nonnull obj) {
            return ![recycleBin contains:obj];
        }];
    }
    
    [self smartInitializeSearch];
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

    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self.searchController.searchBar becomeFirstResponder];
    });
}

- (NSArray<Node *> *)getDataSource {
    return (self.searchController.isActive ? self.searchResults : self.items);
}

- (IBAction)onCancel:(id)sender {
    [self.rootViewController cancel:nil];
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
            NSURL* url = [NSURL URLWithString:serviceId.identifier];
            
            //NSLog(@"URL: %@", url);
            
            // Direct URL Match?
            
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
        [self.searchController.searchBar setSelectedScopeButtonIndex:kSearchScopeUrl];
        return;
    }
    else {
        NSLog(@"No matches across all fields for Domain: %@", domain);
    }

    // Broadest general search (try grab the company/organisation name from the host)
    
    NSString * searchTerm = getCompanyOrOrganisationNameFromDomain(domain);
    [self.searchController.searchBar setText:searchTerm];
}

- (NSArray<Node*>*)getMatchingItems:(NSString*)searchText scope:(SearchScope)scope {
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.model.database metadata:self.model.metadata];
    
    return [searcher search:searchText
                      scope:scope
                dereference:self.model.metadata.searchDereferencedFields
      includeKeePass1Backup:self.model.metadata.showKeePass1BackupGroup
          includeRecycleBin:self.model.metadata.showRecycleBinInSearchResults];
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
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node *node = [self getDataSource][indexPath.row];
    BrowseItemCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseItemCell forIndexPath:indexPath];
    
    NSString* title = self.model.metadata.viewDereferencedFields ? [self dereference:node.title node:node] : node.title;
    UIImage* icon = [NodeIconHelper getIconForNode:node database:self.model.database];
    NSString *groupLocation = self.searchController.isActive ? [self getGroupPathDisplayString:node] : @"";
    
    if(node.isGroup) {
        BOOL italic = (self.model.database.recycleBinEnabled && node == self.model.database.recycleBinNode);
        
        NSString* childCount = self.model.metadata.showChildCountOnFolderInBrowse ? [NSString stringWithFormat:@"(%lu)", (unsigned long)node.children.count] : @"";
        
        [cell setGroup:title icon:icon childCount:childCount italic:italic groupLocation:groupLocation];
    }
    else {
        DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithDatabase:self.model.database metadata:self.model.metadata];
        
        NSString* subtitle = [searcher getBrowseItemSubtitle:node];
        NSString* flags = node.fields.attachments.count > 0 ? @"📎" : @"";
        flags = self.model.metadata.showFlagsInBrowse ? flags : @"";
       
        [cell setRecord:title
               subtitle:subtitle
                   icon:icon
          groupLocation:groupLocation
                  flags:flags
               otpToken:Settings.sharedInstance.hideTotpInAutoFill ? nil : node.fields.otpToken];
    }
    
    return cell;
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSArray<NSString*> *hierarchy = [vm getTitleHierarchy];
    
    NSString *path = [[hierarchy subarrayWithRange:NSMakeRange(0, hierarchy.count - 1)] componentsJoinedByString:@"/"];
    
    return hierarchy.count == 1 ? @"(in /)" : [NSString stringWithFormat:@"(in /%@)", path];
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
    NSString* suggestedTitle = nil;
    NSString* suggestedUrl = nil;
    
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];
    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = [NSURL URLWithString:serviceId.identifier];
            if(url && url.host.length) {
                NSString* foo = getCompanyOrOrganisationNameFromDomain(url.host);
                suggestedTitle = foo.length ? [foo capitalizedString] : foo;
                suggestedUrl = [[url.scheme stringByAppendingString:@"://"] stringByAppendingString:url.host];
            }
            else {
                suggestedUrl = serviceId.identifier;
            }
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            NSString* foo = getCompanyOrOrganisationNameFromDomain(serviceId.identifier);
            suggestedTitle = foo.length ? [foo capitalizedString] : foo;
            suggestedUrl = serviceId.identifier;
        }
    }

    //UINavigationController* nav = segue.destinationViewController;
    ItemDetailsViewController* vc = (ItemDetailsViewController*)segue.destinationViewController;
    
    vc.createNewItem = YES;
    vc.item = nil;
    vc.parentGroup = self.model.database.rootGroup;
    vc.readOnly = NO;
    vc.databaseModel = self.model;
    vc.autoFillRootViewController = self.rootViewController;
    vc.autoFillSuggestedUrl = suggestedUrl;
    vc.autoFillSuggestedTitle = suggestedTitle;
}

- (BOOL)canCreateNewCredential {
    return [self.rootViewController isLiveAutoFillProvider:self.model.metadata.storageProvider] && !self.model.isReadOnly;
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    if([self canCreateNewCredential]) {
        [self segueToCreateNew];
    }
    else {
        [Alerts info:self title:@"Unsupported Storage" message:@"This database is stored on a Storage Provider that does not support Live editing in App Extensions. Cannot Create New Record."];
    }
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    NSDictionary *attributes = @{
                                 NSFontAttributeName: [UIFont systemFontOfSize:16.0f],
                                 NSForegroundColorAttributeName: [UIColor blueColor]
                                 };
    
    return [[NSAttributedString alloc] initWithString: @"Create New Record..." attributes:attributes];
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = self.searchController.isActive ? @"No Matching Records" : @"Empty Database";
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0f],
                                 NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text = self.searchController.isActive ? @"Could not find any matching records" : @"It appears your database is empty";
    
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

- (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint tapLocation = [self.longPressRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:tapLocation];
    
    if (!indexPath || indexPath.row >= [self getDataSource].count) {
        NSLog(@"Not on a cell");
        return;
    }
    
    Node *item = [self getDataSource][indexPath.row];
    
    if (item.isGroup) {
        NSLog(@"Item is group, cannot Fast PW Copy...");
        return;
    }
    
    NSLog(@"Fast Password Copy on %@", item.title);

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    BOOL copyTotp = (item.fields.password.length == 0 && item.fields.otpToken);
    pasteboard.string = copyTotp ? item.fields.otpToken.password : [self dereference:item.fields.password node:item];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.tapCount == 1 && self.tapTimer != nil && [self.tappedIndexPath isEqual:indexPath]){
        [self.tapTimer invalidate];
        
        self.tapTimer = nil;
        self.tapCount = 0;
        self.tappedIndexPath = nil;
        
        [self handleDoubleTap:indexPath];
    }
    else if(self.tapCount == 0){
        //This is the first tap. If there is no tap till tapTimer is fired, it is a single tap
        self.tapCount = self.tapCount + 1;
        self.tappedIndexPath = indexPath;
        self.tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(tapTimerFired:) userInfo:nil repeats:NO];
    }
    else if(![self.tappedIndexPath isEqual:indexPath]){
        //tap on new row
        self.tapCount = 0;
        self.tappedIndexPath = indexPath;
        if(self.tapTimer != nil){
            [self.tapTimer invalidate];
            self.tapTimer = nil;
        }
    }
}

- (void)tapTimerFired:(NSTimer *)aTimer{
    //timer fired, there was a single tap on indexPath.row = tappedRow
    [self tapOnCell:self.tappedIndexPath];
    
    self.tapCount = 0;
    self.tappedIndexPath = nil;
    self.tapTimer = nil;
}

- (void)tapOnCell:(NSIndexPath *)indexPath  {
    NSArray* arr = [self getDataSource];
    if(indexPath.row >= arr.count) {
        return;
    }
    Node *item = arr[indexPath.row];
    if(item) {
        if(!Settings.sharedInstance.doNotCopyOtpCodeOnAutoFillSelect && item.fields.otpToken) {
            NSString* value = item.fields.otpToken.password;
            if (value.length) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = value;
                NSLog(@"Copied TOTP to Pasteboard...");
            }
        }
        
        NSString* user = [self dereference:item.fields.username node:item];
        NSString* password = [self dereference:item.fields.password node:item];
        
        //NSLog(@"Return User/Pass from Node: [%@] - [%@] [%@]", user, password, record);
        
        [self.rootViewController onCredentialSelected:user password:password];
    }
    else {
        NSLog(@"WARN: DidSelectRow with no Record?!");
    }
}

- (void)handleDoubleTap:(NSIndexPath *)indexPath {
    NSArray* arr = [self getDataSource];
    if(indexPath.row >= arr.count) {
        return;
    }
    Node *item = arr[indexPath.row];

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = [self dereference:item.fields.username node:item];
    
    NSLog(@"Fast Username Copy on %@", item.title);
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
