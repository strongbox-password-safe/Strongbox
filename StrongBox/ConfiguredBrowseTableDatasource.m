//
//  ConfiguredBrowseTableDatasource.m
//  Strongbox-iOS
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "ConfiguredBrowseTableDatasource.h"
#import "NSArray+Extensions.h"
#import "DatabaseSearchAndSorter.h"
#import "BrowseTableViewCellHelper.h"
#import "AppPreferences.h"

const NSUInteger kSectionIdxPinned = 0;
const NSUInteger kSectionIdxNearlyExpired = 1;
const NSUInteger kSectionIdxExpired = 2;
const NSUInteger kSectionIdxLast = 3;

@interface ConfiguredBrowseTableDatasource ()

@property Model* viewModel;
@property BOOL isDisplayingRootGroup;

@property (strong, nonatomic) NSArray<Node*> *standardItemsCache;
@property (strong, nonatomic) NSArray<Node*> *pinnedItemsCache;
@property (strong, nonatomic) NSArray<Node*> *expiredItemsCache;
@property (strong, nonatomic) NSArray<Node*> *nearlyExpiredItemsCache;
@property BrowseTableViewCellHelper* cellHelper;

@end

@implementation ConfiguredBrowseTableDatasource

- (instancetype)initWithModel:(Model*)model isDisplayingRootGroup:(BOOL)isDisplayingRootGroup tableView:(UITableView*)tableView {
    self = [super init];
    if (self) {
        self.viewModel = model;
        self.isDisplayingRootGroup = isDisplayingRootGroup;
        self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.viewModel tableView:tableView];
    }
    return self;
}

- (BOOL)supportsSlideActions {
    return YES;
}

- (NSUInteger)sections {
    return  kSectionIdxLast + 1;
}

- (nonnull UITableViewCell *)cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Node* node = [self getNodeFromIndexPath:indexPath];

    BOOL showTotp = self.viewModel.metadata.browseViewType == kBrowseViewTypeTotpList;
    
    return [self.cellHelper getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:showTotp showGroupLocation:NO];
}

- (NSUInteger)rowsForSection:(NSUInteger)section {
    if(!self.isDisplayingRootGroup && section != kSectionIdxLast) {
        return 0;
    }
    else {
        return [self getDataSourceForSection:section].count;
    }
}

- (NSString*)titleForSection:(NSUInteger)section {
    if(section == kSectionIdxPinned && self.isDisplayingRootGroup && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_pinned", @"Section Header Title for Pinned Items");
    }
    else if (section == kSectionIdxNearlyExpired && self.isDisplayingRootGroup && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_nearly_expired", @"Section Header Title for Nearly Expired Items");
    }
    else if (section == kSectionIdxExpired && self.isDisplayingRootGroup && [self getDataSourceForSection:section].count) {
        return NSLocalizedString(@"browse_vc_section_title_expired", @"Section Header Title for Expired Items");
    }
    else if (section == kSectionIdxLast && self.isDisplayingRootGroup){
        if (self.viewModel.metadata.showQuickViewFavourites ||
            self.viewModel.metadata.showQuickViewNearlyExpired ||
            self.viewModel.metadata.showQuickViewExpired) {
            NSUInteger countRows = [self getQuickViewRowCount];
            return countRows ? NSLocalizedString(@"browse_vc_section_title_standard_view", @"Standard View Sections Header") : nil;
        }
    }
    
    return nil;
}



- (NSArray<Node*>*)loadPinnedItems {
    if(!self.viewModel.metadata.showQuickViewFavourites || !self.viewModel.pinnedSet.count) {
        return @[];
    }
    
    BrowseSortField sortField = self.viewModel.metadata.browseSortField;
    BOOL descending = self.viewModel.metadata.browseSortOrderDescending;
    BOOL foldersSeparately = self.viewModel.metadata.browseSortFoldersSeparately;
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.viewModel.database
                                                                       browseSortField:sortField
                                                                            descending:descending
                                                                     foldersSeparately:foldersSeparately
                                                                           checkPinYin:AppPreferences.sharedInstance.pinYinSearchEnabled
                                                                      isFlaggedByAudit:^BOOL(Node * _Nonnull node) {
        return [self.viewModel isFlaggedByAudit:node.uuid];
    }];

    return [searcher filterAndSortForBrowse:self.viewModel.pinnedNodes.mutableCopy
                      includeKeePass1Backup:YES
                          includeRecycleBin:YES
                             includeExpired:YES
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadNearlyExpiredItems {
    if(!self.viewModel.metadata.showQuickViewNearlyExpired) {
        return @[];
    }
    
    NSArray<Node*>* ne = [self.viewModel.database.effectiveRootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.nearlyExpired;
    }];

    BrowseSortField sortField = self.viewModel.metadata.browseSortField;
    BOOL descending = self.viewModel.metadata.browseSortOrderDescending;
    BOOL foldersSeparately = self.viewModel.metadata.browseSortFoldersSeparately;
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.viewModel.database
                                                                       browseSortField:sortField
                                                                            descending:descending
                                                                     foldersSeparately:foldersSeparately
                                                                           checkPinYin:AppPreferences.sharedInstance.pinYinSearchEnabled
                                                                      isFlaggedByAudit:^BOOL(Node * _Nonnull node) {
        return [self.viewModel isFlaggedByAudit:node.uuid];
    }];

    return [searcher filterAndSortForBrowse:ne.mutableCopy
                      includeKeePass1Backup:NO
                          includeRecycleBin:NO
                             includeExpired:NO
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadExpiredItems {
    if(!self.viewModel.metadata.showQuickViewExpired) {
        return @[];
    }
    
    NSArray<Node*>* exp = [self.viewModel.database.effectiveRootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.expired;
    }];

    BrowseSortField sortField = self.viewModel.metadata.browseSortField;
    BOOL descending = self.viewModel.metadata.browseSortOrderDescending;
    BOOL foldersSeparately = self.viewModel.metadata.browseSortFoldersSeparately;
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.viewModel.database
                                                                       browseSortField:sortField
                                                                            descending:descending
                                                                     foldersSeparately:foldersSeparately
                                                                           checkPinYin:AppPreferences.sharedInstance.pinYinSearchEnabled
                                                                      isFlaggedByAudit:^BOOL(Node * _Nonnull node) {
        return [self.viewModel isFlaggedByAudit:node.uuid];
    }];

    return [searcher filterAndSortForBrowse:exp.mutableCopy
                      includeKeePass1Backup:NO
                          includeRecycleBin:NO
                             includeExpired:YES
                              includeGroups:YES];
}

- (NSArray<Node*>*)loadStandardItems:(NSUUID*)currentGroup  {
    NSArray<Node*>* ret = @[];
    
    Node* current = [self.viewModel.database getItemById:currentGroup];
    if (!current) {
        return ret; 
    }
    
    switch (self.viewModel.metadata.browseViewType) {
        case kBrowseViewTypeHierarchy:
            ret = current.children;
            break;
        case kBrowseViewTypeList:
            ret = current.allChildRecords;
            break;
        case kBrowseViewTypeTotpList:
            ret = [self.viewModel.database.effectiveRootGroup.allChildRecords filter:^BOOL(Node * _Nonnull obj) {
                return obj.fields.otpToken != nil;
            }];
            break;
        default:
            break;
    }
    
    BrowseSortField sortField = self.viewModel.metadata.browseSortField;
    BOOL descending = self.viewModel.metadata.browseSortOrderDescending;
    BOOL foldersSeparately = self.viewModel.metadata.browseSortFoldersSeparately;
    DatabaseSearchAndSorter* searcher = [[DatabaseSearchAndSorter alloc] initWithModel:self.viewModel.database
                                                                       browseSortField:sortField
                                                                            descending:descending
                                                                     foldersSeparately:foldersSeparately
                                                                           checkPinYin:AppPreferences.sharedInstance.pinYinSearchEnabled
                                                                      isFlaggedByAudit:^BOOL(Node * _Nonnull node) {
        return [self.viewModel isFlaggedByAudit:node.uuid];
    }];

    return [searcher filterAndSortForBrowse:ret.mutableCopy
                      includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                          includeRecycleBin:!self.viewModel.metadata.doNotShowRecycleBinInBrowse
                             includeExpired:self.viewModel.metadata.showExpiredInBrowse
                              includeGroups:YES];
}

- (void)refreshItems:(NSUUID *)currentGroup {
    self.standardItemsCache = [self loadStandardItems:currentGroup];
    
    
    
    self.pinnedItemsCache = self.isDisplayingRootGroup ? [self loadPinnedItems] : @[];
    self.nearlyExpiredItemsCache = self.isDisplayingRootGroup ? [self loadNearlyExpiredItems] : @[];
    self.expiredItemsCache = self.isDisplayingRootGroup ? [self loadExpiredItems] : @[];
}



- (NSUInteger)getQuickViewRowCount {
    return [self getDataSourceForSection:kSectionIdxPinned].count +
    [self getDataSourceForSection:kSectionIdxNearlyExpired].count +
    [self getDataSourceForSection:kSectionIdxExpired].count;
}

- (NSArray<Node*>*)getDataSourceForSection:(NSUInteger)section {
    if(section == kSectionIdxPinned) {
        return self.pinnedItemsCache;
    }
    else if (section == kSectionIdxNearlyExpired) {
        return self.nearlyExpiredItemsCache;
    }
    else if (section == kSectionIdxExpired) {
        return self.expiredItemsCache;
    }
    else if(section == kSectionIdxLast) {
        return self.standardItemsCache;
    }
    
    NSLog(@"EEEEEEK: WARNWARN: DataSource not found for section");
    return nil;
}

- (Node*)getNodeFromIndexPath:(NSIndexPath*)indexPath {
    NSArray<Node*>* dataSource = [self getDataSourceForSection:indexPath.section];
    
    if(!dataSource || indexPath.row >= dataSource.count) {
        NSLog(@"EEEEEK: WARNWARN - Should never happen but unknown node for indexpath: [%@]", indexPath);
        return nil;
    }
    
    return dataSource[indexPath.row];
}



- (BOOL)canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == kSectionIdxLast &&
    self.viewModel.database.originalFormat != kPasswordSafe &&
    self.viewModel.metadata.browseSortField == kBrowseSortFieldNone &&
    self.viewModel.metadata.browseViewType == kBrowseViewTypeHierarchy;
}

@end
