//
//  DatabaseAuditor.m
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditor.h"
#import "NSArray+Extensions.h"
#import "PasswordMaker.h"
#import "NSString+Levenshtein.h"

@interface DatabaseAuditor ()

@property AuditIsDereferenceableTextBlock isDereferenceable;

@property AuditProgressBlock progress;
@property AuditCompletionBlock completion;
@property AuditNodesChangedBlock nodesChanged;

@property BOOL stopRequested;
@property NSSet<Node*>* nodes;
@property DatabaseAuditorConfiguration* config;

// Results

@property NSSet<Node*>* commonPasswords;
@property NSDictionary<NSString*, NSSet<Node*>*>* duplicatedPasswords;
@property NSSet<Node*>* noPasswords;
@property NSDictionary<NSUUID*, NSSet<Node*>*>* similar;
@property NSSet<Node*>* tooShort;

@property NSSet<Node*>* duplicatedPasswordsNodeSet; // PERF
@property NSSet<Node*>* similarPasswordsNodeSet; // PERF

@property BOOL isPro;

@end

@implementation DatabaseAuditor

- (instancetype)initWithPro:(BOOL)pro {
    self = [super init];
    
    if (self) {
        self.state = kAuditStateInitial;
    
        self.commonPasswords = NSSet.set;
        self.duplicatedPasswords = @{};
        self.noPasswords = NSSet.set;
        self.tooShort = NSSet.set;
        
        self.similar = @{};
        self.duplicatedPasswordsNodeSet = NSSet.set;
        self.similarPasswordsNodeSet = NSSet.set;
        self.isPro = pro;
    }
    
    return self;
}

- (BOOL)start:(NSArray<Node *> *)nodes
       config:(DatabaseAuditorConfiguration *)config
isDereferenceable:(AuditIsDereferenceableTextBlock)isDereferenceable
 nodesChanged:(AuditNodesChangedBlock)nodesChanged
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion {
    if (self.state != kAuditStateInitial) {
        NSLog(@"Audit cannot be started as it has already been run or is running");
        return NO;
    }

    self.state = kAuditStateRunning;

    self.isDereferenceable = isDereferenceable;

    self.completion = completion;
    self.nodesChanged = nodesChanged;
    self.progress = progress;

    self.nodes = nodes.copy;
    self.config = config;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [self audit];
    });
    
    return YES;
}

- (void)audit {
    NSLog(@"AUDIT: Starting Audit...");
    
    self.progress(0.0);

    [self performAudits];
    
    self.progress(1.0);

    if (self.state == kAuditStateRunning) { // Don't overwrite stopped incomplete
        self.state = kAuditStateDone;
    }
    
    self.completion(self.state == kAuditStateStoppedIncomplete);
}

- (void)stop {
    NSLog(@"AUDIT: Stopping Audit...");
    self.stopRequested = YES;
}

- (DatabaseAuditReport *)getAuditReport {
    DatabaseAuditReport* report = [[DatabaseAuditReport alloc] initWithNoPasswordEntries:self.noPasswords
                                                                     duplicatedPasswords:self.duplicatedPasswords
                                                                         commonPasswords:self.commonPasswords
                                                                                 similar:self.similar
                                                                                tooShort:self.tooShort];
    
    return report;
}

- (NSString *)getQuickAuditVeryBriefSummaryForNode:(Node *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];
    
    if (flags.anyObject) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_no_password_set", @"No Password");
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_very_common_password", @"Weak/Common");
        }
        
        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_duplicated_password", @"Duplicated");
        }
        
        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_password_is_similar_to_another", @"Similar");
        }
        
        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_password_is_too_short", @"Short");
        }
    }
    
    return @"";
}

- (NSString *)getQuickAuditSummaryForNode:(Node *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];
    
    if (flags.anyObject) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_no_password_set", @"Audit: No password set");
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_common_password", @"Audit: Password is very common");
        }
        
        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            return NSLocalizedString(@"audit_quick_summary_duplicated_password", @"Audit: Password is duplicated in another entry");
        }
        
        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_similar_to_another", @"Audit: Password is similar to one in another entry.=");
        }
        
        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_too_short", @"Audit: Password is too short.=");
        }
    }
    
    return @"";
}

- (NSSet<NSNumber *> *)getQuickAuditFlagsForNode:(Node *)node {
    NSMutableSet<NSNumber*>* ret = NSMutableSet.set;
    
    if ([self.noPasswords containsObject:node]) {
        [ret addObject:@(kAuditFlagNoPassword)];
    }

    if ([self.commonPasswords containsObject:node]) {
        [ret addObject:@(kAuditFlagCommonPassword)];
    }

    if ([self.duplicatedPasswordsNodeSet containsObject:node]) {
        [ret addObject:@(kAuditFlagDuplicatePassword)];
    }

    if ([self.similarPasswordsNodeSet containsObject:node]) {
        [ret addObject:@(kAuditFlagSimilarPassword)];
    }

    if ([self.tooShort containsObject:node]) {
        [ret addObject:@(kAuditFlagTooShort)];
    }

    return ret;
}

- (NSUInteger)auditIssueNodeCount {
    NSMutableSet* set = [NSMutableSet setWithSet:self.noPasswords];
    
    [set addObjectsFromArray:self.commonPasswords.allObjects];
    [set addObjectsFromArray:self.duplicatedPasswordsNodeSet.allObjects];
    [set addObjectsFromArray:self.similarPasswordsNodeSet.allObjects];
    [set addObjectsFromArray:self.tooShort.allObjects];
    
    return set.count;
}

- (NSUInteger)auditIssueCount {
    return self.noPasswords.count + self.commonPasswords.count + self.duplicatedPasswordsNodeSet.count + self.similarPasswordsNodeSet.count + self.tooShort.count;
}

- (void)performAudits {
    // No Passwords
    
    self.noPasswords = [self checkForNoPasswords];

    // Duplicated Passwords within DB

    self.duplicatedPasswords = [self checkForDuplicatedPasswords];
    self.duplicatedPasswordsNodeSet = [NSSet setWithArray:[self.duplicatedPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }]];

    // Common Weak/Popular Passwords

    self.commonPasswords = [self checkForCommonPasswords];

    // Too Short
    
    self.tooShort = [self checkForTooShort];
    
    // Batch up these fast ones into a single notification
    
    if (self.tooShort.anyObject || self.noPasswords.anyObject || self.duplicatedPasswordsNodeSet.anyObject || self.commonPasswords.anyObject) {
         self.nodesChanged();
    }

    // Similar

    if (self.isPro) {
        self.similar = [self checkForSimilarPasswords];
        self.similarPasswordsNodeSet = [NSSet setWithArray:[self.similar.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }]];

        if (self.similarPasswordsNodeSet.anyObject) {
             self.nodesChanged();
        }
    }
            
    // Future Extensions: Extend Audit to these
    //
    // Weak (Low Entropy)
    // Weak - In Have I Been Pwned
    // Weak Master Creds (Low Entropy & no Key File/YubiKey)
    // Allow for an Ignore list (Groups and Entries)
    
    //    return [[DatabaseAuditReport alloc] initWithNoPasswordEntries:noPasswords duplicatedPasswords:duplicatedPasswords commonPasswords:commonPasswords similar:similar];

    //    return nil;

}

- (NSSet<Node*>*)checkForNoPasswords {
    if (!self.config.checkForNoPasswords) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length == 0;
    }];

    return [NSSet setWithArray:results];
}

- (NSSet<Node*>*)checkForTooShort {
    if (!self.config.checkForMinimumLength) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length > 0 && obj.fields.password.length < self.config.minimumLength; // Exclude  empties
    }];

    return [NSSet setWithArray:results];
}

- (NSDictionary<NSString*, NSSet<Node*>*>*)checkForDuplicatedPasswords {
    if (!self.config.checkForDuplicatedPasswords) {
        return NSDictionary.dictionary;
    }
    
    NSMutableDictionary<NSString*, NSMutableSet<Node*>*>* possibleDupes = NSMutableDictionary.dictionary;
    
    for (Node* entry in self.nodes) {
        // FUTURE: Detect historical entries with same passwords?
        NSString* password = entry.fields.password;
        
        // Exclude Field References and Empties...

        if (password.length == 0 || self.isDereferenceable(password)) {
            continue;
        }
        
        if (self.config.caseInsensitiveMatchForDuplicates) {
            password = password.lowercaseString;
        }
        
        NSMutableSet<Node*>* existing = possibleDupes[password];
        if(existing) {
            [existing addObject:entry];
        }
        else {
            possibleDupes[password] = [NSMutableSet setWithObject:entry];
        }
    }
    
    // Filter out singles...
    
    NSMutableDictionary<NSString*, NSSet<Node*>*> *dupes = NSMutableDictionary.dictionary;
    for (NSString* password in possibleDupes.allKeys) {
        NSSet<Node*>* nodes = possibleDupes[password];
        if (nodes.count > 1) {
            dupes[password] = nodes.copy;
        }
    }
    
    return dupes.copy;
}

- (NSSet<Node*>*)checkForCommonPasswords {
    if (!self.config.checkForCommonPasswords) {
         return NSSet.set;
    }

    NSArray<Node*>* common = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        if (self.isDereferenceable(obj.fields.password)) {
            return NO;
        }

        return [PasswordMaker.sharedInstance isCommonPassword:obj.fields.password];
    }];
    
    return [NSSet setWithArray:common];
}

- (NSDictionary<NSUUID*, NSSet<Node*>*>*)checkForSimilarPasswords {
    if (!self.config.checkForSimilarPasswords) {
        return NSDictionary.dictionary;
    }
    
    NSArray<Node*>* activeNonRefs = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length && !self.isDereferenceable(obj.fields.password);
    }];
    
    NSMutableArray<Node*>* uncheckedOthers = activeNonRefs.mutableCopy; // Avoid N^2 Cartesian Product... eeek - Can we then rejoin and normalize?

    NSMutableDictionary<NSUUID*, NSMutableSet<Node*>*>* similarGroups = NSMutableDictionary.dictionary;
    
    int i=0;
    int n = (int)activeNonRefs.count - 1;
    int totalComparisons = (n * (n + 1)) / 2; // Good olde Carl Gauss
    
    NSLog(@"AUDIT: Similarity Comparisons required = %d", totalComparisons);
    for (Node* entry in activeNonRefs) {
        NSString* password = entry.fields.password;

        [uncheckedOthers removeObject:entry];

        for (Node* other in uncheckedOthers) {
            if (i % 500 == 0) {
                //                NSLog(@"%d/%d", i, totalComparisons);
                CGFloat progress = (CGFloat)i/(CGFloat)totalComparisons; // FUTURE: Weight this against other tasks
                self.progress(progress);
            }
            i++;

            if (self.stopRequested) {
                self.state = kAuditStateStoppedIncomplete;
                return similarGroups.copy;
            }
            
            // (Levenstein) -     // Levenshtein distance (https://en.wikipedia.org/wiki/Levenshtein_distance).

            NSString* otherPassword = other.fields.password;
            
            if ([password isEqualToString:otherPassword]) {
                continue; // Skip exact duplicates - FUTURE maybe we should include?
            }
            
            double similarity = [password levenshteinSimilarityRatio:otherPassword];

            if (similarity >= self.config.levenshteinSimilarityThreshold) {
                NSLog(@"[%@] - [%@] - Levenshtein Similarity = [%f]", password, otherPassword, similarity);

                if(!similarGroups[entry.uuid]) {
                    similarGroups[entry.uuid] = [NSMutableSet setWithObject:entry];
                }
                
                [similarGroups[entry.uuid] addObject:other];
            }
        }
    }
    
    return similarGroups.copy;
}

@end
