//
//  DatabaseAuditReport.m
//  Strongbox
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditReport.h"
#import "NSArray+Extensions.h"

@interface DatabaseAuditReport ()

@property NSSet<Node*>* noPasswords;
@property NSDictionary<NSString*, NSSet<Node *>*>* duplicatedPasswords;
@property NSSet<Node*>* commonPasswords;
@property NSDictionary<NSString*, NSSet<Node *>*>* similarPasswords;
@property NSSet<Node*>* tooShort;
@property NSSet<Node*>* pwned;

@end

@implementation DatabaseAuditReport

- (instancetype)initWithNoPasswordEntries:(NSSet<Node *> *)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString *,NSSet<Node *> *> *)duplicatedPasswords
                          commonPasswords:(NSSet<Node *> *)commonPasswords
                                  similar:(nonnull NSDictionary<NSUUID *,NSSet<Node *> *> *)similar
                                 tooShort:(NSSet<Node *> *)tooShort
                                    pwned:(NSSet<Node *> *)pwned {
    self = [super init];
    
    if (self) {
        self.noPasswords = noPasswords.copy;
        self.duplicatedPasswords = duplicatedPasswords.copy;
        self.commonPasswords = commonPasswords.copy;
        self.similarPasswords = similar.copy;
        self.tooShort = tooShort.copy;
        self.pwned = pwned.copy;
    }
    
    return self;
}

- (NSSet<Node *> *)entriesWithNoPasswords {
    return self.noPasswords;
}

- (NSSet<Node *> *)entriesWithDuplicatePasswords {
    NSArray<Node*>* flattened = [self.duplicatedPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }];
    
    return [NSSet setWithArray:flattened];
}

- (NSSet<Node *> *)entriesWithCommonPasswords {
    return self.commonPasswords;
}

- (NSSet<Node *> *)entriesWithSimilarPasswords {
    NSArray<Node*>* flattened = [self.similarPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }];
    
    return [NSSet setWithArray:flattened];
}

- (NSSet<Node *> *)entriesTooShort {
    return self.tooShort;
}

- (NSSet<Node *> *)entriesPwned {
    return self.pwned;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"No Passswords = [%@], Duplicates = [%@], Common = [%@], Similar = [%@], tooShort = [%@], pwned = [%@]",
            self.noPasswords, self.duplicatedPasswords, self.commonPasswords, self.similarPasswords, self.tooShort, self.pwned];
}

@end
