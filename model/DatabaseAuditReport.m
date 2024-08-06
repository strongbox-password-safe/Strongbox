//
//  DatabaseAuditReport.m
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditReport.h"
#import "NSArray+Extensions.h"

@interface DatabaseAuditReport ()

@property NSSet<NSUUID*>* noPasswords;
@property NSDictionary<NSString*, NSSet<NSUUID *>*>* duplicatedPasswords;
@property NSSet<NSUUID*>* commonPasswords;
@property NSDictionary<NSUUID*, NSSet<NSUUID *>*>* similarPasswords;
@property NSSet<NSUUID*>* tooShort;
@property NSSet<NSUUID*>* pwned;
@property NSSet<NSUUID*>* lowEntropy;
@property NSSet<NSUUID*>* twoFactorAvailable;

@end

@implementation DatabaseAuditReport

- (instancetype)init {
    return [self initWithNoPasswordEntries:NSSet.set
                       duplicatedPasswords:NSDictionary.dictionary
                           commonPasswords:NSSet.set
                                   similar:NSDictionary.dictionary
                                  tooShort:NSSet.set
                                     pwned:NSSet.set
                                lowEntropy:NSSet.set
                        twoFactorAvailable:NSSet.set];
}

- (instancetype)initWithNoPasswordEntries:(NSSet<NSUUID *> *)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString *,NSSet<NSUUID *> *> *)duplicatedPasswords
                          commonPasswords:(NSSet<NSUUID *> *)commonPasswords
                                  similar:(nonnull NSDictionary<NSUUID *,NSSet<NSUUID *> *> *)similar
                                 tooShort:(NSSet<NSUUID *> *)tooShort
                                    pwned:(NSSet<NSUUID *> *)pwned
                               lowEntropy:(NSSet<NSUUID *> *)lowEntropy
                       twoFactorAvailable:(NSSet<NSUUID *> *)twoFactorAvailable {
    self = [super init];
    
    if (self) {
        self.noPasswords = noPasswords.copy;
        self.duplicatedPasswords = duplicatedPasswords.copy;
        self.commonPasswords = commonPasswords.copy;
        self.similarPasswords = similar.copy;
        self.tooShort = tooShort.copy;
        self.pwned = pwned.copy;
        self.lowEntropy = lowEntropy.copy;
        self.twoFactorAvailable = twoFactorAvailable;
    }
    
    return self;
}

- (NSSet<NSUUID *> *)entriesWithNoPasswords {
    return self.noPasswords;
}

- (NSSet<NSUUID *> *)entriesWithDuplicatePasswords {
    NSArray<NSUUID*>* flattened = [self.duplicatedPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<NSUUID *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }];
    
    return [NSSet setWithArray:flattened];
}

- (NSDictionary<NSString *,NSSet<NSUUID *> *> *)duplicatedDictionary {
    return self.duplicatedPasswords;
}

- (NSDictionary<NSUUID *,NSSet<NSUUID *> *> *)similarDictionary {
    return self.similarPasswords;
}

- (NSSet<NSUUID *> *)entriesWithCommonPasswords {
    return self.commonPasswords;
}

- (NSSet<NSUUID *> *)entriesWithSimilarPasswords {
    NSArray<NSUUID*>* flattened = [self.similarPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<NSUUID *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }];
    
    return [NSSet setWithArray:flattened];
}

- (NSSet<NSUUID *> *)entriesTooShort {
    return self.tooShort;
}

- (NSSet<NSUUID *> *)entriesPwned {
    return self.pwned;
}

- (NSSet<NSUUID *> *)entriesWithLowEntropyPasswords {
    return self.lowEntropy;
}

- (NSSet<NSUUID *> *)entriesWithTwoFactorAvailable {
    return self.twoFactorAvailable;
}

- (NSSet<NSUUID *> *)allEntries {
    NSMutableSet* all = [NSMutableSet setWithSet:self.noPasswords];
    
    [all unionSet:self.entriesWithDuplicatePasswords];
    [all unionSet:self.commonPasswords];
    [all unionSet:self.entriesWithSimilarPasswords];
    [all unionSet:self.tooShort];
    [all unionSet:self.pwned];
    [all unionSet:self.lowEntropy];
    [all unionSet:self.twoFactorAvailable];
    
    return all;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"No Passswords = [%@], Duplicates = [%@], Common = [%@], Similar = [%@], tooShort = [%@], pwned = [%@], lowEntropy = [%@], 2faAvail = [%@]",
            self.noPasswords, self.duplicatedPasswords, self.commonPasswords, self.similarPasswords, self.tooShort, self.pwned, self.lowEntropy, self.twoFactorAvailable];
}

@end
