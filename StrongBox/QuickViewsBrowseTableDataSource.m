//
//  QuickViewsBrowseTableDataSource.m
//  Strongbox
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "QuickViewsBrowseTableDataSource.h"
#import "Utils.h"
#import "SearchScope.h"
#import "QuickViewConfig.h"

static NSString* const kBrowseQuickViewItemCell = @"BrowseQuickViewItemCell";

static NSUInteger const kQuickViewSectionIdx = 0;

@interface QuickViewsBrowseTableDataSource ()

@property Model* viewModel;
@property UITableView* tableView;
@property NSArray<QuickViewConfig*> *quickViews;

@end

@implementation QuickViewsBrowseTableDataSource

- (instancetype)initWithModel:(Model*)model tableView:(nonnull UITableView *)tableView {
    self = [super init];
    if (self) {
        self.tableView = tableView;
        [self.tableView registerNib:[UINib nibWithNibName:kBrowseQuickViewItemCell bundle:nil] forCellReuseIdentifier:kBrowseQuickViewItemCell];
        
        self.viewModel = model;

        [self refresh];
    }
    
    return self;
}

- (void)refresh {
    NSMutableArray<QuickViewConfig*>* ret = @[].mutableCopy;

    NSUInteger auditCount = self.viewModel.auditIssueNodeCount;
    
    if ( auditCount ) {
        NSString *loc3 = NSLocalizedString(@"quick_view_title_audit_issues_title_fmt", @"Audit Issues (%ld)");
        NSString* title = [NSString stringWithFormat:loc3, auditCount];
        NSString *loc4 = NSLocalizedString(@"quick_view_title_audit_issues_subtitle", @"View all entries with audit issues");
        
        UIImage* auditImage = [UIImage systemImageNamed:@"checkmark.shield"];

        QuickViewConfig *auditEntries = [QuickViewConfig title:title subtitle:loc4 image:auditImage searchTerm:kSpecialSearchTermAuditEntries imageTint:UIColor.systemOrangeColor];
        
        [ret addObject:auditEntries];
    }
    
    NSUInteger expiredCount = self.viewModel.database.expiredEntries.count;
    if ( expiredCount > 0 ) {
        NSString *loc5 = NSLocalizedString(@"quick_view_title_expired_entries_title_fmt", @"Expired Entries (%@)");
        NSString* title = [NSString stringWithFormat:loc5, @(expiredCount)];
        NSString *loc6 = NSLocalizedString(@"quick_view_title_expired_entries_subtitle", @"View all expired entries");

        UIImage* image = [UIImage systemImageNamed:@"timelapse"];
        
        QuickViewConfig *entries = [QuickViewConfig title:title subtitle:loc6 image:image searchTerm:kSpecialSearchTermExpiredEntries];
        
        [ret addObject:entries];
    }

    NSUInteger nearlyExpiredCount = self.viewModel.database.nearlyExpiredEntries.count;
    if ( nearlyExpiredCount > 0 ) {
        NSString *loc5 = NSLocalizedString(@"quick_view_title_nearly_expired_entries_title_fmt", @"Nearly Expired Entries (%@)");
        NSString* title = [NSString stringWithFormat:loc5, @(nearlyExpiredCount)];

        NSString *loc6 = NSLocalizedString(@"quick_view_title_nearly_expired_entries_subtitle", @"View all nearly expired entries");

        UIImage* image = [UIImage systemImageNamed:@"clock.arrow.2.circlepath"];
        
        QuickViewConfig *entries = [QuickViewConfig title:title subtitle:loc6 image:image searchTerm:kSpecialSearchTermNearlyExpiredEntries];
        
        [ret addObject:entries];
    }

    self.quickViews = ret.copy;
}

- (BOOL)supportsSlideActions {
    return NO;
}

- (NSUInteger)sections {
    return 1;
}

- (nonnull UITableViewCell *)cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell* cell = [self.tableView dequeueReusableCellWithIdentifier:kBrowseQuickViewItemCell forIndexPath:indexPath];

    if (indexPath.section == kQuickViewSectionIdx) {
        QuickViewConfig* config = self.quickViews[indexPath.row];
        
        cell.textLabel.text = config.title;
        cell.detailTextLabel.text = config.subtitle;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

        cell.imageView.image = config.image;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        cell.imageView.tintColor = config.imageTint;
    }
    else { 
        NSLog(@"🔴 QuickViewsBrowseTableDataSource::cellForRowAtIndexPath called but section not known [%@]", indexPath);
        









    }

    return cell;
}

- (NSUInteger)rowsForSection:(NSUInteger)section {
    return self.quickViews.count;
}

- (NSString*)titleForSection:(NSUInteger)section {
    return self.quickViews.count == 0 ? nil : NSLocalizedString(@"quick_view_section_title_quick_views", @"Quick Views");
}

- (Node *)getParamFromIndexPath:(nonnull NSIndexPath *)indexPath {
    return nil;
}

- (void)performTapAction:(NSIndexPath *)indexPath searchController:(UISearchController *)searchController {
    if ( indexPath.row < self.quickViews.count ) {
        QuickViewConfig *config = self.quickViews[indexPath.row];

        searchController.searchBar.selectedScopeButtonIndex = kSearchScopeAll;
        searchController.searchBar.text = config.searchTerm;
        
        [searchController.searchBar endEditing:YES]; 
    }
}

- (BOOL)canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSArray<NSString *> *)sectionIndexTitles {
    return @[];
}

- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return index;
}

@end
