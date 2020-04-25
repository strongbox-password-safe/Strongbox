//
//  QuickViewsBrowseTableDataSource.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "QuickViewsBrowseTableDataSource.h"
#import "Utils.h"
#import "SearchScope.h"
#import "QuickViewConfig.h"
#import "DatabaseSearchAndSorter.h"

static NSString* const kBrowseQuickViewItemCell = @"BrowseQuickViewItemCell";

static NSUInteger const kQuickViewSectionIdx = 0;
static NSUInteger const kTagSectionIdx = 1;

@interface QuickViewsBrowseTableDataSource ()

@property Model* viewModel;
@property UITableView* tableView;
@property NSArray<QuickViewConfig*> *quickViews;
//@property NSArray<NSString*> *tags;

@end

@implementation QuickViewsBrowseTableDataSource

- (instancetype)initWithModel:(Model*)model tableView:(nonnull UITableView *)tableView {
    self = [super init];
    if (self) {
        self.tableView = tableView;
        [self.tableView registerNib:[UINib nibWithNibName:kBrowseQuickViewItemCell bundle:nil] forCellReuseIdentifier:kBrowseQuickViewItemCell];
        
        self.viewModel = model;

        QuickViewConfig *allItems, *auditEntries, *totpEntries;

        NSString *loc1 = NSLocalizedString(@"quick_view_title_all_entries_title", @"All Entries");
        NSString *loc2 = NSLocalizedString(@"quick_view_title_all_entries_subtitle", @"View every entry in a flat list...");
        allItems = [QuickViewConfig title:loc1 subtitle:loc2 image:[UIImage imageNamed:@"globe"] searchTerm:kSpecialSearchTermAllEntries];
        
        NSString *loc3 = NSLocalizedString(@"quick_view_title_audit_issues_title", @"Audit Issues");
        NSString *loc4 = NSLocalizedString(@"quick_view_title_audit_issues_subtitle", @"View all entries with audit issues");
        auditEntries = [QuickViewConfig title:loc3 subtitle:loc4 image:[UIImage imageNamed:@"error"] searchTerm:kSpecialSearchTermAuditEntries];
        
        NSString *loc5 = NSLocalizedString(@"quick_view_title_totp_entries_title", @"TOTP Entries");
        NSString *loc6 = NSLocalizedString(@"quick_view_title_totp_entries_subtitle", @"View all entries with a TOTP token");
        totpEntries = [QuickViewConfig title:loc5 subtitle:loc6 image:[UIImage imageNamed:@"timer"] searchTerm:kSpecialSearchTermTotpEntries];

        if (@available(iOS 13.0, *)) {
            allItems.image = [UIImage systemImageNamed:@"globe"];
            auditEntries.image = [UIImage systemImageNamed:@"exclamationmark.triangle"];
            totpEntries.image = [UIImage systemImageNamed:@"timer"];
        }
        self.quickViews = @[allItems, auditEntries, totpEntries];
        
        [self refresh];
    }
    
    return self;
}

- (void)refresh {
    // TODO: Perf - Tags cache
}

- (BOOL)supportsSlideActions {
    return NO;
}

- (NSUInteger)sections {
    BOOL hasTags = self.viewModel.database.tagSet.anyObject != nil;
    return hasTags ? 2 : 1;
}

- (nonnull UITableViewCell *)cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseQuickViewItemCell forIndexPath:indexPath];

    if (indexPath.section == kQuickViewSectionIdx) {
        QuickViewConfig* config = self.quickViews[indexPath.row];
        
        cell.textLabel.text = config.title;
        cell.detailTextLabel.text = config.subtitle;
        if (@available(iOS 13.0, *)) {
            cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        }
        cell.imageView.image = config.image;

    }
    else { // Tags
        NSArray<NSString*>* tags = [self.viewModel.database.tagSet.allObjects sortedArrayUsingComparator:finderStringComparator];
        NSString* tag = tags[indexPath.row];

        cell.textLabel.text = tag;
        cell.detailTextLabel.text = @"";
        if (@available(iOS 13.0, *)) {
            cell.imageView.image = [UIImage systemImageNamed:@"tag"];
        }
        else {
            cell.imageView.image = [UIImage imageNamed:@"price_tag"];
        }
    }

    return cell;
}

- (NSUInteger)rowsForSection:(NSUInteger)section {
    if (section == kTagSectionIdx) {
        NSArray<NSString*>* tags = [self.viewModel.database.tagSet.allObjects sortedArrayUsingComparator:finderStringComparator];
        return tags.count;
    }
    
    return self.quickViews.count;
}

- (NSString*)titleForSection:(NSUInteger)section {
    return section == kQuickViewSectionIdx ? NSLocalizedString(@"quick_view_section_title_quick_views", @"Quick Views") : NSLocalizedString(@"browse_vc_search_scope_tags", @"Tags");
}

- (Node *)getNodeFromIndexPath:(nonnull NSIndexPath *)indexPath {
    return nil;
}

- (void)performTapAction:(NSIndexPath *)indexPath searchController:(UISearchController *)searchController {
    if (indexPath.section == kQuickViewSectionIdx) {
        QuickViewConfig *config = self.quickViews[indexPath.row];

        searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
        searchController.searchBar.text = config.searchTerm;
        
        [searchController.searchBar endEditing:YES]; // Hide Keyboard after search
    }
    else if (indexPath.section == kTagSectionIdx) {
        NSArray<NSString*>* tags = [self.viewModel.database.tagSet.allObjects sortedArrayUsingComparator:finderStringComparator];
        NSString* tag = tags[indexPath.row];

        searchController.searchBar.selectedScopeButtonIndex = kSearchScopeTags;
        searchController.searchBar.text = tag;

        [searchController.searchBar endEditing:YES]; // Hide Keyboard after search
    }
}

@end
