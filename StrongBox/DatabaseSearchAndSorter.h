//
//  DatabaseSearchAndSorter.h
//  Strongbox
//
//  Created by Mark on 21/06/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "Node.h"
#import "SearchScope.h"
#import "SafeMetaData.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseSearchAndSorter : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDatabase:(DatabaseModel*)database metadata:(SafeMetaData*)metadata;

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired;

- (NSArray<Node*>*)searchNodes:(NSArray<Node*>*)nodes
                    searchText:(NSString *)searchText
                         scope:(SearchScope)scope
                   dereference:(BOOL)dereference
         includeKeePass1Backup:(BOOL)includeKeePass1Backup
             includeRecycleBin:(BOOL)includeRecycleBin
                includeExpired:(BOOL)includeExpired;

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired;

- (NSString*)getBrowseItemSubtitle:(Node*)node;

@end

NS_ASSUME_NONNULL_END
