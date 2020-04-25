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
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSpecialSearchTermAllEntries;
extern NSString* const kSpecialSearchTermAuditEntries;
extern NSString* const kSpecialSearchTermTotpEntries;
          
@interface DatabaseSearchAndSorter : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithModel:(Model*)model;

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups;

- (NSArray<Node*>*)searchNodes:(NSArray<Node*>*)nodes
                    searchText:(NSString *)searchText
                         scope:(SearchScope)scope
                   dereference:(BOOL)dereference
         includeKeePass1Backup:(BOOL)includeKeePass1Backup
             includeRecycleBin:(BOOL)includeRecycleBin
                includeExpired:(BOOL)includeExpired
                 includeGroups:(BOOL)includeGroups;

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired
                            includeGroups:(BOOL)includeGroups;

- (NSString*)getBrowseItemSubtitle:(Node*)node;

@end

NS_ASSUME_NONNULL_END
