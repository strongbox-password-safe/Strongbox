//
//  DatabaseAuditReport.h
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAuditReport : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNoPasswordEntries:(NSSet<Node*>*)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString*, NSSet<Node*>*>*)duplicatedPasswords
                          commonPasswords:(NSSet<Node*>* )commonPasswords
                                  similar:(NSDictionary<NSUUID*, NSSet<Node*>*>*)similar NS_DESIGNATED_INITIALIZER;

@property (readonly) NSSet<Node*>* entriesWithNoPasswords;
@property (readonly) NSSet<Node*>* entriesWithDuplicatePasswords;
- (NSSet<Node*>*)duplicatedPasswordEntriesForEntry:(Node*)entry;
@property (readonly) NSSet<Node*>* entriesWithCommonPasswords;
@property (readonly) NSSet<Node*>* entriesWithSimilarPasswords;

@end

NS_ASSUME_NONNULL_END
