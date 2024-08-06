//
//  SearchResultsBrowseTableDatasource.m
//  Strongbox-iOS
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SearchResultsBrowseTableDatasource.h"
#import "BrowseTableViewCellHelper.h"
#import "BrowseSortField.h"
#import "DatabaseModel.h"
#import "AppPreferences.h"

@interface SearchResultsBrowseTableDatasource ()

@property (strong, nonatomic) NSArray<Node*> *searchResults;
@property Model* viewModel;
@property BrowseTableViewCellHelper* cellHelper;

@end

@implementation SearchResultsBrowseTableDatasource

- (instancetype)initWithModel:(Model*)model tableView:(nonnull UITableView *)tableView {
    self = [super init];
    if (self) {
        self.viewModel = model;
        self.cellHelper = [[BrowseTableViewCellHelper alloc] initWithModel:self.viewModel tableView:tableView];
    }
    return self;
}

- (BOOL)supportsSlideActions {
    return YES;
}

- (NSUInteger)sections {
    return 1;
}

- (nonnull UITableViewCell *)cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    Node* node = [self getParamFromIndexPath:indexPath];
    
    return [self.cellHelper getBrowseCellForNode:node indexPath:indexPath showLargeTotpCell:NO showGroupLocation:YES];
}

- (NSUInteger)rowsForSection:(NSUInteger)section {
    return self.searchResults.count;
}

- (NSString*)titleForSection:(NSUInteger)section {
    return nil;
}

- (id)getParamFromIndexPath:(NSIndexPath *)indexPath {
    NSArray<Node*>* dataSource = self.searchResults;
    
    if(!dataSource || indexPath.row >= dataSource.count) {
        slog(@"EEEEEK: WARNWARN - Should never happen but unknown node for indexpath: [%@]", indexPath);
        return nil;
    }
    
    return dataSource[indexPath.row];
}

- (void)updateSearchResults:(NSString*)searchText scope:(SearchScope)scope {
    BrowseSortConfiguration* sortConfig = [self.viewModel getDefaultSortConfiguration];
    
    BrowseSortField sortField = sortConfig.field;
    BOOL descending = sortConfig.descending;
    BOOL foldersSeparately = sortConfig.foldersOnTop;

    self.searchResults = [self.viewModel search:searchText
                                          scope:scope
                                    dereference:self.viewModel.metadata.searchDereferencedFields
                          includeKeePass1Backup:self.viewModel.metadata.showKeePass1BackupGroup
                              includeRecycleBin:self.viewModel.metadata.showRecycleBinInSearchResults
                                 includeExpired:self.viewModel.metadata.showExpiredInSearch
                                  includeGroups:YES
                                       trueRoot:YES
                                browseSortField:sortField
                                     descending:descending
                              foldersSeparately:foldersSeparately];
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
