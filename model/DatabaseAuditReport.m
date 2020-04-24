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

@end

@implementation DatabaseAuditReport

- (instancetype)initWithNoPasswordEntries:(NSSet<Node *> *)noPasswords
                      duplicatedPasswords:(NSDictionary<NSString *,NSSet<Node *> *> *)duplicatedPasswords
                          commonPasswords:(NSSet<Node *> *)commonPasswords
                                  similar:(nonnull NSDictionary<NSUUID *,NSSet<Node *> *> *)similar {
    self = [super init];
    
    if (self) {
        self.noPasswords = noPasswords.copy;
        self.duplicatedPasswords = duplicatedPasswords.copy;
        self.commonPasswords = commonPasswords.copy;
        self.similarPasswords = similar.copy;
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

- (NSSet<Node *> *)duplicatedPasswordEntriesForEntry:(Node *)entry {
    
    return nil; // TODO:
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

- (NSString *)description {
    return [NSString stringWithFormat:@"No Passswords = [%@], Duplicates = [%@], Common = [%@], Similar = [%@]", self.noPasswords, self.duplicatedPasswords, self.commonPasswords, self.similarPasswords];
}

@end
