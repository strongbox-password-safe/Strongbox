//
//  PickCredentialsTableViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 14/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PickCredentialsTableViewController.h"

@interface PickCredentialsTableViewController () <UISearchBarDelegate, UISearchResultsUpdating>

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property (strong, nonatomic) NSArray<Node*> *items;
@property (strong, nonatomic) UISearchController *searchController;

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
    
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.definesPresentationContext = YES;
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    self.searchController.searchBar.delegate = self;
    self.searchController.searchBar.scopeButtonTitles = @[@"Title", @"Username", @"Password", @"All Fields"];
    self.searchController.searchBar.selectedScopeButtonIndex = 3;
    
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        // We want the search bar visible all the time.
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.tableView.tableHeaderView = self.searchController.searchBar;
        [self.searchController.searchBar sizeToFit];
    }
    
    self.tableView.rowHeight = 75.0f;
    
    self.items = self.model.allRecords;
    
    [self.searchController.searchBar setText:[self getInitialSearchString]];
}

- (NSString*)getInitialSearchString {
    NSArray<ASCredentialServiceIdentifier *> *serviceIdentifiers = [self.rootViewController getCredentialServiceIdentifiers];
    
    NSLog(@"Service Identifiers: [%@]", serviceIdentifiers);
    
    ASCredentialServiceIdentifier *serviceId = [serviceIdentifiers firstObject];
    
    if(serviceId) {
        if(serviceId.type == ASCredentialServiceIdentifierTypeURL) {
            NSURL* url = [NSURL URLWithString:serviceId.identifier];
            
            return url.host;
        }
    }
    
    return @"";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController setToolbarHidden:NO];
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
    else {
        predicate = [NSPredicate predicateWithFormat:@"title contains[c] %@ "
                     @"OR fields.password contains[c] %@  "
                     @"OR fields.username contains[c] %@  "
                     @"OR fields.email contains[c] %@  "
                     @"OR fields.url contains[c] %@ "
                     @"OR fields.notes contains[c] %@",
                     searchText, searchText, searchText, searchText, searchText, searchText];
    }
    
    NSArray<Node*> *foo = [self.model.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup && [predicate evaluateWithObject:node];
    }];
    
    self.searchResults = [foo sortedArrayUsingComparator:searchResultsComparator];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.searchController];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self getDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"OpenSafeViewCell" forIndexPath:indexPath];
    Node *vm = [self getDataSource][indexPath.row];
    
    NSString *groupLocation = (self.searchController.isActive ? [self getGroupPathDisplayString:vm] : vm.fields.username);
    
    cell.textLabel.text = vm.isGroup ? vm.title :
    (self.searchController.isActive ? [NSString stringWithFormat:@"%@%@", vm.title, vm.fields.username.length ? [NSString stringWithFormat:@" [%@]" ,vm.fields.username] : @""] :
     vm.title);
    
    cell.detailTextLabel.text = groupLocation;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.image = [UIImage imageNamed:@"lock-64.png"];
    
    return cell;
}

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSArray<NSString*> *hierarchy = [vm getTitleHierarchy];
    
    NSString *path = [[hierarchy subarrayWithRange:NSMakeRange(0, hierarchy.count - 1)] componentsJoinedByString:@"/"];
    
    return hierarchy.count == 1 ? @"(in /)" : [NSString stringWithFormat:@"(in /%@)", path];
}

@end
