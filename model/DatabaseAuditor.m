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
@property BOOL stopRequested;
@property NSSet<Node*>* nodes;
@property DatabaseAuditorConfiguration* config;

// Results

@property NSSet<Node*>* commonPasswords;
@property NSDictionary<NSString*, NSSet<Node*>*>* duplicatedPasswords;
@property NSSet<Node*>* noPasswords;
@property NSDictionary<NSUUID*, NSSet<Node*>*>* similar;

@property NSSet<Node*>* duplicatedPasswordsNodeSet; // PERF
@property NSSet<Node*>* similarPasswordsNodeSet; // PERF

@end

@implementation DatabaseAuditor

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.state = kAuditStateInitial;
    
        self.commonPasswords = NSSet.set;
        self.duplicatedPasswords = @{};
        self.noPasswords = NSSet.set;
        self.similar = @{};
        self.duplicatedPasswordsNodeSet = NSSet.set;
        self.similarPasswordsNodeSet = NSSet.set;
    }
    
    return self;
}

- (BOOL)start:(NSArray<Node *> *)nodes
       config:(DatabaseAuditorConfiguration *)config
isDereferenceable:(AuditIsDereferenceableTextBlock)isDereferenceable
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion {
    if (self.state != kAuditStateInitial) {
        NSLog(@"Audit cannot be started as it has already been run or is running");
        return NO;
    }

    self.state = kAuditStateRunning;
    self.completion = completion;
    self.isDereferenceable = isDereferenceable;
    self.progress = progress;
    self.nodes = nodes.copy;
    self.config = config;
    
    self.progress(0.0);
    
    // Do express audits now... very fast and allows immediate display in browse on Unlock

    [self performExpressAudits];
    
    // Possibly Longer running...
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [self performComprehensiveAudits];
        
        self.completion(self.state == kAuditStateStoppedIncomplete);
    });
    
    return YES;
}

- (void)stop {
    self.stopRequested = YES; // TODO:
}

- (DatabaseAuditReport *)getAuditReport {
    DatabaseAuditReport* report = [[DatabaseAuditReport alloc] initWithNoPasswordEntries:self.noPasswords
                                                                     duplicatedPasswords:self.duplicatedPasswords
                                                                         commonPasswords:self.commonPasswords
                                                                                 similar:self.similar]; // TODO:
    
    return report;
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
    if ([self.similarPasswordsNodeSet containsObject:node]) { // TODO: Incremental - It would be good to have this work while audit in progress
        [ret addObject:@(kAuditFlagSimilarPassword)];
    }
    
    return ret;
}

- (void)performExpressAudits {
    self.noPasswords = [self checkForNoPasswords];
    self.duplicatedPasswords = [self checkForDuplicatedPasswords];
    self.commonPasswords = [self checkForCommonPasswords];

    self.duplicatedPasswordsNodeSet = [NSSet setWithArray:[self.duplicatedPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }]];
}

- (void)performComprehensiveAudits {

    // Similar

    self.similar = [self checkForSimilarPasswords];
    self.similarPasswordsNodeSet = [NSSet setWithArray:[self.similar.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }]];
    
    // Future Extensions: Extend Audit to these
    //
    // Weak (Low Entropy)
    // Weak - In Have I Been Pwned
    // Weak Master Creds (Low Entropy & no Key File/YubiKey)
    // Allow for an Ignore list (Groups and Entries)
    
    //    return [[DatabaseAuditReport alloc] initWithNoPasswordEntries:noPasswords duplicatedPasswords:duplicatedPasswords commonPasswords:commonPasswords similar:similar];

//    return nil;

    self.progress(1.0);
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

- (NSDictionary<NSString*, NSSet<Node*>*>*)checkForDuplicatedPasswords {
    if (!self.config.checkForDuplicatedPasswords) {
        return NSDictionary.dictionary;
    }
    
    NSMutableDictionary<NSString*, NSMutableSet<Node*>*>* possibleDupes = NSMutableDictionary.dictionary;
    
    for (Node* entry in self.nodes) {
        // FUTURE: Detect historical entries with same passwords?
        NSString* password = entry.fields.password;
        
        // Exclude Field References...

        if (self.isDereferenceable(password)) {
            continue;
        }
        
        if (self.config.caseInsensitiveMatchForDuplicates) { // TODO: In UI you will need to present these differently or grab the unique case?
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
            if (i % 1000 == 0) {
                //                NSLog(@"%d/%d", i, totalComparisons);
                CGFloat progress = (CGFloat)i/(CGFloat)totalComparisons; // FUTURE: Weight this against other tasks
                self.progress(progress);
            }
            i++;
            
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
