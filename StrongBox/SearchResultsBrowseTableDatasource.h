//
//  SearchResultsBrowseTableDatasource.h
//  Strongbox-iOS
//
//  Created by Mark on 24/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BrowseTableDatasource.h"
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface SearchResultsBrowseTableDatasource : NSObject <BrowseTableDatasource>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithModel:(Model*)model tableView:(UITableView*)tableView NS_DESIGNATED_INITIALIZER;

- (void)updateSearchResults:(NSString*)searchText scope:(SearchScope)scope;

@end

NS_ASSUME_NONNULL_END
