//
//  DatabaseAuditReport.h
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAuditReport : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNoPasswordEntries:(NSSet<NSUUID*>*)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString*, NSSet<NSUUID*>*>*)duplicatedPasswords
                          commonPasswords:(NSSet<NSUUID*>* )commonPasswords
                                  similar:(NSDictionary<NSUUID*, NSSet<NSUUID*>*>*)similar
                                 tooShort:(NSSet<NSUUID *> *)tooShort
                                    pwned:(NSSet<NSUUID *> *)pwned NS_DESIGNATED_INITIALIZER;

@property (readonly) NSSet<NSUUID*>* entriesWithNoPasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithDuplicatePasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithCommonPasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithSimilarPasswords;
@property (readonly) NSSet<NSUUID*>* entriesTooShort;
@property (readonly) NSSet<NSUUID*>* entriesPwned;

@end

NS_ASSUME_NONNULL_END
