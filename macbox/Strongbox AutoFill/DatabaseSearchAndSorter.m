//
//  DatabaseSearchAndSorter.m
//  Strongbox
//
//  Created by Mark on 21/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseSearchAndSorter.h"
#import "SprCompilation.h"
#import "NSMutableArray+Extensions.h"
#import "NSArray+Extensions.h"
#import "Utils.h"
#import "NSDate+Extensions.h"

NSString* const kSpecialSearchTermAllEntries = @"strongbox:allEntries";
NSString* const kSpecialSearchTermAuditEntries = @"strongbox:auditEntries";
NSString* const kSpecialSearchTermTotpEntries = @"strongbox:totpEntries";
          
@interface DatabaseSearchAndSorter ()

@property DatabaseModel* database;
@property (copy, nullable) FlaggedByAuditPredicate isFlaggedByAudit;
@property BrowseSortField browseSortField;
@property BOOL descending;
@property BOOL foldersSeparately;
@property BOOL checkPinYin;
@end

@implementation DatabaseSearchAndSorter

- (instancetype)initWithModel:(DatabaseModel *)databaseModel browseSortField:(BrowseSortField)browseSortField descending:(BOOL)descending foldersSeparately:(BOOL)foldersSeparately checkPinYin:(BOOL)checkPinYin {
    return [self initWithModel:databaseModel browseSortField:browseSortField descending:descending foldersSeparately:foldersSeparately checkPinYin:checkPinYin isFlaggedByAudit:nil];
}

- (instancetype)initWithModel:(DatabaseModel *)databaseModel
              browseSortField:(BrowseSortField)browseSortField
                   descending:(BOOL)descending
            foldersSeparately:(BOOL)foldersSeparately
                  checkPinYin:(BOOL)checkPinYin
             isFlaggedByAudit:(FlaggedByAuditPredicate)isFlaggedByAudit {
    self = [super init];
    
    if (self) {
        self.database = databaseModel;
        self.isFlaggedByAudit = isFlaggedByAudit;
        self.browseSortField = browseSortField;
        self.descending = descending;
        self.foldersSeparately= foldersSeparately;
        self.checkPinYin = checkPinYin;
    }
    
    return self;
}


- (NSString*)maybeDeref:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self dereference:text node:node] : text;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    if(self.database.originalFormat == kPasswordSafe || !text.length) {
        return text;
    }
    
    NSError* error;
    
    BOOL isCompilable = [SprCompilation.sharedInstance isSprCompilable:text];
    
    NSString* compiled = isCompilable ? [SprCompilation.sharedInstance sprCompile:text node:node database:self.database error:&error] : text;
    
    if(error) {
        NSLog(@"WARN: SPR Compilation ERROR: [%@]", error);
    }
    
    return compiled ? compiled : @""; 
}

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups {
    return [self search:searchText
                  scope:scope
            dereference:dereference
  includeKeePass1Backup:includeKeePass1Backup
      includeRecycleBin:includeRecycleBin
         includeExpired:includeExpired
          includeGroups:includeGroups
               trueRoot:NO];
}

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(SearchScope)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin
           includeExpired:(BOOL)includeExpired
            includeGroups:(BOOL)includeGroups
                 trueRoot:(BOOL)trueRoot {
    NSArray<Node*>* nodes = trueRoot ? self.database.allSearchableTrueRoot : self.database.allSearchable;
    
    return [self searchNodes:nodes
                  searchText:searchText
                       scope:scope
                 dereference:dereference
       includeKeePass1Backup:includeKeePass1Backup
           includeRecycleBin:includeRecycleBin
              includeExpired:includeExpired
               includeGroups:includeGroups];
}

- (NSArray<Node*>*)searchNodes:(NSArray<Node*>*)nodes
                    searchText:(NSString *)searchText
                         scope:(SearchScope)scope
                   dereference:(BOOL)dereference
         includeKeePass1Backup:(BOOL)includeKeePass1Backup
             includeRecycleBin:(BOOL)includeRecycleBin
                includeExpired:(BOOL)includeExpired
                 includeGroups:(BOOL)includeGroups {
    NSMutableArray* results = [nodes mutableCopy]; 
    
    NSArray<NSString*>* terms = [self.database getSearchTerms:searchText];
    
    for (NSString* word in terms) {
        [self filterForWord:results
                 searchText:word
                      scope:scope
                dereference:dereference];
    }
    
    return [self filterAndSortForBrowse:results
                  includeKeePass1Backup:includeKeePass1Backup
                      includeRecycleBin:includeRecycleBin
                         includeExpired:includeExpired
                          includeGroups:includeGroups];
}

- (NSArray<Node*>*)filterAndSortForBrowse:(NSMutableArray<Node*>*)nodes
                    includeKeePass1Backup:(BOOL)includeKeePass1Backup
                        includeRecycleBin:(BOOL)includeRecycleBin
                           includeExpired:(BOOL)includeExpired
                            includeGroups:(BOOL)includeGroups {
    [self filterExcluded:nodes
   includeKeePass1Backup:includeKeePass1Backup
       includeRecycleBin:includeRecycleBin
          includeExpired:includeExpired
           includeGroups:includeGroups];
    
    return [self sortItemsForBrowse:nodes];
}

- (void)filterForWord:(NSMutableArray<Node*>*)searchNodes
           searchText:(NSString *)searchText
                scope:(NSInteger)scope
          dereference:(BOOL)dereference {
    if ([searchText isEqualToString:kSpecialSearchTermAllEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.isGroup;
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermAuditEntries] ) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return self.isFlaggedByAudit && self.isFlaggedByAudit(obj);
        }];
    }
    else if ([searchText isEqualToString:kSpecialSearchTermTotpEntries]) { 
        [searchNodes mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj.fields.otpToken != nil;
        }];
    }
    else if (scope == kSearchScopeTitle) {
        [self searchTitle:searchNodes searchText:searchText dereference:dereference checkPinYin:self.checkPinYin];
    }
    else if (scope == kSearchScopeUsername) {
        [self searchUsername:searchNodes searchText:searchText dereference:dereference checkPinYin:self.checkPinYin];
    }
    else if (scope == kSearchScopePassword) {
        [self searchPassword:searchNodes searchText:searchText dereference:dereference checkPinYin:self.checkPinYin];
    }
    else if (scope == kSearchScopeUrl) {
        [self searchUrl:searchNodes searchText:searchText dereference:dereference checkPinYin:self.checkPinYin];
    }
    else if (scope == kSearchScopeTags) {
        [self searchTags:searchNodes searchText:searchText checkPinYin:self.checkPinYin];
    }
    else {
        [self searchAllFields:searchNodes searchText:searchText dereference:dereference checkPinYin:self.checkPinYin];
    }
}

- (void)searchTitle:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isTitleMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchUsername:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUsernameMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchPassword:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isPasswordMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchUrl:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isUrlMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)searchTags:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isTagsMatches:searchText node:node checkPinYin:checkPinYin];
    }];
}

- (void)searchAllFields:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference checkPinYin:(BOOL)checkPinYin {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self.database isAllFieldsMatches:searchText node:node dereference:dereference checkPinYin:checkPinYin];
    }];
}

- (void)filterExcluded:(NSMutableArray<Node*>*)matches
 includeKeePass1Backup:(BOOL)includeKeePass1Backup
     includeRecycleBin:(BOOL)includeRecycleBin
        includeExpired:(BOOL)includeExpired
         includeGroups:(BOOL)includeGroups {
    if(!includeKeePass1Backup) {
        if (self.database.originalFormat == kKeePass1) {
            Node* backupGroup = self.database.keePass1BackupNode;
            if(backupGroup) {
                [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
                    return (obj != backupGroup && ![backupGroup contains:obj]);
                }];
            }
        }
    }

    Node* recycleBin = self.database.recycleBinNode;
    if(!includeRecycleBin && recycleBin) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj != recycleBin && ![recycleBin contains:obj];
        }];
    }

    if(!includeExpired) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.expired;
        }];
    }
    
    if(!includeGroups) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return !obj.isGroup;
        }];
    }
}

- (NSArray<Node*>*)sortItemsForBrowse:(NSArray<Node*>*)items {
    BrowseSortField field = self.browseSortField;
    
    if(field == kBrowseSortFieldEmail && self.database.originalFormat != kPasswordSafe) {
        field = kBrowseSortFieldTitle;
    }
    else if(field == kBrowseSortFieldNone && self.database.originalFormat == kPasswordSafe) {
        field = kBrowseSortFieldTitle;
    }
    
    if(field != kBrowseSortFieldNone) {
        return [items sortedArrayWithOptions:NSSortStable
                             usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                                 Node* n1 = (Node*)obj1;
                                 Node* n2 = (Node*)obj2;
                                 
                                 return [self compareNodesForSort:n1 node2:n2 field:field descending:self.descending foldersSeparately:self.foldersSeparately];
                             }];
    }
    else { 
        if ( self.foldersSeparately ) { 
            
            return [items sortedArrayWithOptions:NSSortStable
                                 usingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                Node* node1 = (Node*)obj1;
                Node* node2 = (Node*)obj2;
                
                if ( node1.isGroup == node2.isGroup ) {
                    return NSOrderedSame;
                }
                
                return node1.isGroup ? NSOrderedAscending : NSOrderedDescending;
            }];
        }
        else {
            return items;
        }
    }
}

- (NSComparisonResult)compareNodesForSort:(Node*)node1
                                    node2:(Node*)node2
                                    field:(BrowseSortField)field
                               descending:(BOOL)descending
                        foldersSeparately:(BOOL)foldersSeparately {
    if(foldersSeparately) {
        if(node1.isGroup && !node2.isGroup) {
            return NSOrderedAscending;
        }
        else if(!node1.isGroup && node2.isGroup) {
            return NSOrderedDescending;
        }
    }
    
    
    
    if(node2.isGroup && node1.isGroup && field != kBrowseSortFieldTitle) {
        return finderStringCompare(node1.title, node2.title);
    }
    
    Node* n1 = descending ? node2 : node1;
    Node* n2 = descending ? node1 : node2;
    
    NSComparisonResult result = NSOrderedSame;
    
    if(field == kBrowseSortFieldTitle) {
        result = finderStringCompare(n1.title, n2.title);
    }
    else if(field == kBrowseSortFieldUsername) {
        result = finderStringCompare(n1.fields.username, n2.fields.username);
    }
    else if(field == kBrowseSortFieldPassword) {
        result = finderStringCompare(n1.fields.password, n2.fields.password);
    }
    else if(field == kBrowseSortFieldUrl) {
        result = finderStringCompare(n1.fields.url, n2.fields.url);
    }
    else if(field == kBrowseSortFieldEmail) {
        result = finderStringCompare(n1.fields.email, n2.fields.email);
    }
    else if(field == kBrowseSortFieldNotes) {
        result = finderStringCompare(n1.fields.notes, n2.fields.notes);
    }
    else if(field == kBrowseSortFieldCreated) {
        result = [n1.fields.created compare:n2.fields.created];
    }
    else if(field == kBrowseSortFieldModified) {
        result = [n1.fields.modified compare:n2.fields.modified];
    }
    
    
    
    if(result == NSOrderedSame && field != kBrowseSortFieldTitle) {
        result = finderStringCompare(n1.title, n2.title);
    }
    
    return result;
}

@end
