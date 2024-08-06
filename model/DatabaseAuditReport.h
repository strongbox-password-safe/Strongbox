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

- (instancetype)init;

- (instancetype)initWithNoPasswordEntries:(NSSet<NSUUID*>*)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString*, NSSet<NSUUID*>*>*)duplicatedPasswords
                          commonPasswords:(NSSet<NSUUID*>* )commonPasswords
                                  similar:(NSDictionary<NSUUID*, NSSet<NSUUID*>*>*)similar
                                 tooShort:(NSSet<NSUUID *> *)tooShort
                                    pwned:(NSSet<NSUUID *> *)pwned
                               lowEntropy:(NSSet<NSUUID *> *)lowEntropy
                       twoFactorAvailable:(NSSet<NSUUID *> *)twoFactorAvailable NS_DESIGNATED_INITIALIZER;

@property (readonly) NSSet<NSUUID*>* entriesWithNoPasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithDuplicatePasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithCommonPasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithSimilarPasswords;
@property (readonly) NSSet<NSUUID*>* entriesTooShort;
@property (readonly) NSSet<NSUUID*>* entriesPwned;
@property (readonly) NSSet<NSUUID*>* entriesWithLowEntropyPasswords;
@property (readonly) NSSet<NSUUID*>* entriesWithTwoFactorAvailable;
@property (readonly) NSSet<NSUUID*>* allEntries;

@property (readonly) NSDictionary<NSString*, NSSet<NSUUID*>*>* duplicatedDictionary;
@property (readonly) NSDictionary<NSUUID*, NSSet<NSUUID*>*>* similarDictionary;

@end

NS_ASSUME_NONNULL_END
