//
//  DatabaseSearchAndSorter.h
//  Strongbox
//
//  Created by Mark on 21/06/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "Node.h"
#import "SearchScope.h"
#import "BrowseSortField.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const kSpecialSearchTermAllEntries;
extern NSString* const kSpecialSearchTermAuditEntries;
extern NSString* const kSpecialSearchTermTotpEntries;
          
typedef BOOL (^FlaggedByAuditPredicate)(Node* node);
 
@interface DatabaseSearchAndSorter : NSObject

- (instancetype)init NS_UNAVAILABLE;

















































@end

NS_ASSUME_NONNULL_END
