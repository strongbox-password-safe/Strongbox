//
//  PickCredentialsTableViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PickCredentialsTableViewController.h"
#import "NodeIconHelper.h"
#import "BrowseSafeEntryTableViewCell.h"
#import "Settings.h"
#import "NSArray+Extensions.h"
#import "Node+OTPToken.h"
#import "OTPToken+Generation.h"
#import "CreateCredentialTableViewController.h"
#import "Alerts.h"
#import "Utils.h"
#import "regdom.h"

@interface PickCredentialsTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonAddCredential;

@property NSTimer* timerRefreshOtp;

@end

@implementation PickCredentialsTableViewController

static NSComparator searchResultsComparator = ^(id obj1, id obj2) {
    Node* n1 = (Node*)obj1;
    Node* n2 = (Node*)obj2;
    
    if(n1.isGroup && !n2.isGroup) {
        return NSOrderedDescending;
    }
    else if(!n1.isGroup && n2.isGroup) {
        return NSOrderedAscending;
    }
    
    NSComparisonResult result = [n1.title compare:n2.title options:NSCaseInsensitiveSearch];
    
    if(result == NSOrderedSame) {
        return [n1.title compare:n2.title];
    }
    
    return result;
};

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.buttonAddCredential.enabled = [self canCreateNewCredential];
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles = @[@"Title", @"Username", @"Password", @"URL", @"All Fields"];
    self.searchController.searchBar.selectedScopeButtonIndex = 4;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        // We want the search bar visible all the time.
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        [self.searchController.searchBar sizeToFit];
    }
        
    self.items = self.model.database.allRecords;
    
    // Filter KeePass1 Backup Group if so configured...
    
    if(!Settings.sharedInstance.showKeePass1BackupGroup) {
        if (self.model.database.format == kKeePass1) {
            Node* backupGroup = [self.model.database.rootGroup findFirstChild:NO predicate:^BOOL(Node * _Nonnull node) {
                return [node.title isEqualToString:@"Backup"];
            }];
            
            if(backupGroup) {
                self.items = [self.model.database.allRecords filter:^BOOL(Node * _Nonnull obj) {
                    return ![backupGroup contains:obj];
                }];
            }
        }
    }
    
    [self smartInitializeSearch];
}

- (void)smartInitializeSearch {
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];
    
    if(serviceIdentifiers.count > 1) {
        NSLog(@"Service Identifiers > 1: [%@]", serviceIdentifiers);
    }
    
    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = [NSURL URLWithString:serviceId.identifier];

            NSLog(@"URL: %@", url);

            NSString * searchTerm = getSearchTermFromDomain(url.host);
        
            //self.searchController.searchBar.selectedScopeButtonIndex = 0; // Title
            [self.searchController.searchBar setText:searchTerm];
            return;
        }
        else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
            NSString * searchTerm = getSearchTermFromDomain(serviceId.identifier);
            
            //self.searchController.searchBar.selectedScopeButtonIndex = 0;
            [self.searchController.searchBar setText:searchTerm];
        
            return;
        }
    }
    
    //self.searchController.searchBar.selectedScopeButtonIndex = 0; // Title
    //[self.searchController.searchBar setText:@""];
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
    
    if(!Settings.sharedInstance.hideTotpInBrowse) {
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
    
    [self filterContentForSearchText:searchString scope:searchController.searchBar.selectedScopeButtonIndex];
    [self.tableView reloadData];
}

- (void)filterContentForSearchText:(NSString *)searchText scope:(NSInteger)scope {
    if(!searchText.length) {
        self.searchResults = self.items;
        return;
    }
    
    NSPredicate *predicate;
    
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
    else if (scope == 3)
    {
        predicate = [NSPredicate predicateWithFormat:@"fields.url contains[c] %@", searchText];
    }
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ "
                     @"OR fields.password contains[c] %@  "
                     @"OR fields.username contains[c] %@  "
                     @"OR fields.email contains[c] %@  "
                     @"OR fields.url contains[c] %@ "
                     @"OR fields.notes contains[c] %@",
                     searchText, searchText, searchText, searchText, searchText, searchText];
    }
    
    NSArray<Node*> *foo = [self.model.database.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [predicate evaluateWithObject:node];
    }];
    
    // Filter out any results from the KDB root 'Backup' group/folder if configured so...
    
    if(!Settings.sharedInstance.showKeePass1BackupGroup) {
        if (self.model.database.format == kKeePass1) {
            Node* backupGroup = [self.model.database.rootGroup findFirstChild:NO predicate:^BOOL(Node * _Nonnull node) {
                return [node.title isEqualToString:@"Backup"];
            }];
            
            if(backupGroup) {
                foo = [foo filter:^BOOL(Node * _Nonnull obj) {
                    return (obj != backupGroup && ![backupGroup contains:obj]);
                }];
            }
        }
    }

    self.searchResults = [foo sortedArrayUsingComparator:searchResultsComparator];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    Node *node = [self getDataSource][indexPath.row];
    if(node.isGroup) {
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"FolderCell" forIndexPath:indexPath];
        cell.textLabel.text = node.title;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [NodeIconHelper getIconForNode:node database:self.model.database];

        return cell;
    }
    else {
        BrowseSafeEntryTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
        
        NSString *groupLocation = self.searchController.isActive ? [self getGroupPathDisplayString:node] : @"";
        
        cell.title.text = node.title;
        cell.username.text = node.fields.username;
        cell.path.text = groupLocation;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.icon.image = [NodeIconHelper getIconForNode:node database:self.model.database];
        cell.flags.text = node.fields.attachments.count > 0 ? @"📎" : @"";
        
        if(!Settings.sharedInstance.hideTotpInAutoFill && node.otpToken) {
            uint64_t remainingSeconds = node.otpToken.period - ((uint64_t)([NSDate date].timeIntervalSince1970) % (uint64_t)node.otpToken.period);
            
            cell.otpCode.text = [NSString stringWithFormat:@"%@", node.otpToken.password];
            cell.otpCode.textColor = (remainingSeconds < 5) ? [UIColor redColor] : (remainingSeconds < 9) ? [UIColor orangeColor] : [UIColor blueColor];
            
            cell.otpCode.alpha = 1;
            
            if(remainingSeconds < 16) {
                [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse animations:^{
                    cell.otpCode.alpha = 0.5;
                } completion:nil];
            }
        }
        else {
            cell.otpCode.text = @"";
        }

        return cell;
    }
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSArray<NSString*> *hierarchy = [vm getTitleHierarchy];
    
    NSString *path = [[hierarchy subarrayWithRange:NSMakeRange(0, hierarchy.count - 1)] componentsJoinedByString:@"/"];
    
    return hierarchy.count == 1 ? @"(in /)" : [NSString stringWithFormat:@"(in /%@)", path];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Node* record = [[self getDataSource] objectAtIndex:indexPath.row];

    if(record) {
        NSLog(@"[%@] selected... Sending credentials [%@/%@]...", record.title, record.fields.username, record.fields.password);
        [self.rootViewController onCredentialSelected:record.fields.username password:record.fields.password];
    }
    else {
        NSLog(@"WARN: DidSelectRow with no Record?!");
    }
}

- (IBAction)onAddCredential:(id)sender {
    [self performSegueWithIdentifier:@"segueToAdd" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"segueToAdd"]) {
        CreateCredentialTableViewController *vc = segue.destinationViewController;
        
        vc.viewModel = self.model;
        vc.rootViewController = self.rootViewController;

        NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];
        ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
        if(serviceId) {
            if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
                NSURL* url = [NSURL URLWithString:serviceId.identifier];
                if(url && url.host.length) {
                    NSString* foo = getSearchTermFromDomain(url.host);
                    vc.suggestedTitle = foo.length ? [foo capitalizedString] : foo;
                    vc.suggestedUrl = [[url.scheme stringByAppendingString:@"://"] stringByAppendingString:url.host];
                }
                else {
                    vc.suggestedUrl = serviceId.identifier;
                }
                return;
            }
            else if (serviceId.type == ASCredentialServiceIdentifierTypeDomain) {
                NSString* foo = getSearchTermFromDomain(serviceId.identifier);
                vc.suggestedTitle = foo.length ? [foo capitalizedString] : foo;
                vc.suggestedUrl = serviceId.identifier;
                return;
            }
        }
    }
}

- (BOOL)canCreateNewCredential {
    return [self.rootViewController isLiveAutoFillProvider:self.model.metadata.storageProvider];
}

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    if([self canCreateNewCredential]) {
        [self performSegueWithIdentifier:@"segueToAdd" sender:nil];
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

NSString *getSearchTermFromDomain(NSString* host) {
    NSString* domain = getDomain(host);
    
    if(!domain.length) {
        return domain;
    }
    
    NSArray<NSString*> *parts = [domain componentsSeparatedByString:@"."];
    
    NSLog(@"%@", parts);
    
    NSString *searchTerm =  parts.count ? parts[0] : domain;
    return searchTerm;
}

@end
