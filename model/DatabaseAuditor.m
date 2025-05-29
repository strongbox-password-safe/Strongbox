//
//  DatabaseAuditor.m
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DatabaseAuditor.h"
#import <DeviceCheck/DeviceCheck.h>
#import "NSArray+Extensions.h"
#import "PasswordMaker.h"
#import "NSString+Levenshtein.h"
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "ConcurrentMutableSet.h"
#import "UrlRequestOperation.h"
#import "SecretStore.h"
#import "Utils.h"
#import "PasswordStrengthTester.h"
#import "NSString+Extensions.h"
#import "Strongbox-Swift.h"

static const int kHttpStatusOk = 200;
static const int kHttpStatusNotFound = 404;
static NSString* const kSecretStoreHibpPwnedSetCacheKey = @"SecretStoreHibpPwnedSetCacheKey";
static NSString* const kSecretStoreBreachedAccountsCacheKey = @"SecretStoreBreachedAccountsCacheKey";

@interface DatabaseAuditor ()


@property AuditProgressBlock progress;
@property AuditCompletionBlock completion;
@property AuditNodesChangedBlock nodesChanged;

@property BOOL stopRequested;
@property DatabaseAuditorConfiguration* config;

@property BOOL isPro;


@property NSSet<NSUUID*>* twoFactorAvailable;
@property NSSet<NSUUID*>* commonPasswords;
@property NSSet<NSUUID*>* lowEntropy;
@property NSDictionary<NSString*, NSSet<NSUUID*>*>* duplicatedPasswords;
@property NSSet<NSUUID*>* noPasswords;
@property NSDictionary<NSUUID*, NSSet<NSUUID*>*>* similar;
@property NSSet<NSUUID*>* tooShort;
@property NSSet<NSUUID*>* duplicatedPasswordsNodeSet; 
@property NSSet<NSUUID*>* similarPasswordsNodeSet;    
@property ConcurrentMutableSet<NSUUID*>* mutablePwnedNodes;
@property ConcurrentMutableSet<NSUUID*>* mutableBreachedAccountNodes;
@property NSOperationQueue *hibpQueue;


@property NSUInteger hibpErrorCount;
@property NSUInteger hibpCompletedCount;
@property NSUInteger hibpTotalCount;
@property CGFloat hibpProgress;
@property CGFloat similarProgress;

@property NSArray<Node*>* auditableNonEmptyPasswordNodes;


@property (nullable) SaveConfigurationBlock saveConfig;
@property (nullable) IsExcludedBlock isExcluded;


@property DatabaseModel* database;
@property PasswordStrengthConfig* strengthConfig;


@property (nonatomic, strong) NSMutableDictionary<NSUUID*, NSArray<NSString*>*>* matchedBreachedDomainsByNode;

@end

@implementation DatabaseAuditor

const static NSSet<NSString*>* kTwoFactorDomains;

+ (void)initialize {
    if(self == [DatabaseAuditor class]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kTwoFactorDomains = [DatabaseAuditor loadTwoFactorDomains];
        });
    }
}

- (instancetype)initWithPro:(BOOL)pro { 
    return [self initWithPro:pro strengthConfig:nil isExcluded:nil saveConfig:nil];
}

- (instancetype)initWithPro:(BOOL)pro
              strengthConfig:(PasswordStrengthConfig *)strengthConfig
                  isExcluded:(IsExcludedBlock)isExcluded
                   saveConfig:(SaveConfigurationBlock)saveConfig {
    self = [super init];

    if (self) {
        self.state = kAuditStateInitial;

        self.twoFactorAvailable = NSSet.set;
        self.commonPasswords = NSSet.set;
        self.lowEntropy = NSSet.set;
        self.duplicatedPasswords = @{};
        self.noPasswords = NSSet.set;
        self.tooShort = NSSet.set;
        self.similar = @{};
        self.duplicatedPasswordsNodeSet = NSSet.set;
        self.similarPasswordsNodeSet = NSSet.set;
        self.isPro = pro;

        self.hibpQueue = [NSOperationQueue new];
        self.hibpQueue.maxConcurrentOperationCount = 4;
        self.mutablePwnedNodes = ConcurrentMutableSet.mutableSet;
        self.mutableBreachedAccountNodes = ConcurrentMutableSet.mutableSet;

        
        self.matchedBreachedDomainsByNode = [NSMutableDictionary dictionary];

        self.isExcluded = (isExcluded != nil) ? isExcluded : ^BOOL(Node * _Nonnull item) {
            return NO;
        };
        self.saveConfig = saveConfig;
        self.strengthConfig = strengthConfig;

        
        [self fetchAndStoreDeviceCheckToken];
    }

    return self;
}

+ (NSSet<NSString*>*)loadTwoFactorDomains {
    NSString *path = [NSBundle.mainBundle pathForResource:@"twofactorauth" ofType:@"json"];

    NSData *data = [NSData dataWithContentsOfFile:path];

    if (data) {
        NSArray<NSString*> *domains = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        return domains.set;
    }

    slog(@"🔴 Could not load twofactorauth.json");

    return NSSet.set;
}

- (BOOL)start:(DatabaseModel*)database
       config:(DatabaseAuditorConfiguration *)config
 nodesChanged:(AuditNodesChangedBlock)nodesChanged
     progress:(AuditProgressBlock)progress
   completion:(AuditCompletionBlock)completion {
    if (self.state != kAuditStateInitial) {
        slog(@"Audit cannot be started as it has already been run or is running");
        return NO;
    }

    self.state = kAuditStateRunning;
    self.completion = completion;
    self.nodesChanged = nodesChanged;
    self.progress = progress;
    self.config = config;

    self.database = database;

    self.auditableNonEmptyPasswordNodes = [self.database.allSearchableEntries filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length && ![self.database isDereferenceableText:obj.fields.password] && !self.isExcluded(obj);
    }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0L), ^{
        [self audit];
    });

    return YES;
}

- (void)audit {
    slog(@"AUDIT: Starting Audit...");

    self.progress(0.0);

    NSTimeInterval start = NSDate.timeIntervalSinceReferenceDate;

    [self performAudits];

    NSTimeInterval auditDuration = NSDate.timeIntervalSinceReferenceDate - start;

    self.progress(1.0);

    if (self.state == kAuditStateRunning) { 
        self.state = kAuditStateDone;
    }

    self.completion(self.state == kAuditStateStoppedIncomplete, auditDuration);
}

- (void)stop {
    slog(@"AUDIT: Stopping Audit...");
    self.stopRequested = YES;
    [self.hibpQueue cancelAllOperations];
}

- (DatabaseAuditReport *)getAuditReport {
    DatabaseAuditReport* report = [[DatabaseAuditReport alloc] initWithNoPasswordEntries:self.noPasswords
                                                                     duplicatedPasswords:self.duplicatedPasswords
                                                                         commonPasswords:self.commonPasswords
                                                                                 similar:self.similar
                                                                                tooShort:self.tooShort
                                                                                   pwned:self.mutablePwnedNodes.snapshot
                                                                              lowEntropy:self.lowEntropy
                                                                      twoFactorAvailable:self.twoFactorAvailable
                                                                     breachedAccounts:self.mutableBreachedAccountNodes.snapshot];

    return report;
}





- (NSString *)getQuickAuditVeryBriefSummaryForNode:(NSUUID *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];

    if (flags.anyObject != nil) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_no_password_set", @"No Password");
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_very_common_password", @"Weak/Common");
        }

        if ([flags containsObject:@(kAuditFlagPwned)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_password_is_pwned", @"Pwned");
        }

        if ([flags containsObject:@(kAuditFlagBreachedAccount)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_account_breached", @"Account Breached");
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

        if ([flags containsObject:@(kAuditFlagLowEntropy)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_low_entropy", @"Weak/Entropy");
        }

        if ([flags containsObject:@(kAuditFlagTwoFactorAvailable)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_two_factor_available", @"2FA Available");
        }
    }

    return @"";
}

- (NSArray<NSString *>*)getQuickAuditAllIssuesVeryBriefSummaryForNode:(NSUUID *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];

    NSMutableArray<NSString*>* ret = NSMutableArray.array;

    if (flags.anyObject != nil) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_no_password_set", @"No Password")];
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_very_common_password", @"Weak/Common")];
        }

        if ([flags containsObject:@(kAuditFlagPwned)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_password_is_pwned", @"Pwned")];
        }

        if ([flags containsObject:@(kAuditFlagBreachedAccount)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_account_breached", @"Account Breached")];
        }

        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_duplicated_password", @"Duplicated")];
        }

        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_password_is_similar_to_another", @"Similar")];
        }

        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_password_is_too_short", @"Short")];
        }

        if ([flags containsObject:@(kAuditFlagLowEntropy)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_low_entropy", @"Weak/Entropy")];
        }

        if ([flags containsObject:@(kAuditFlagTwoFactorAvailable)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_brief_two_factor_available", @"2FA Available")];
        }
    }

    return ret;
}

- (NSArray<NSString *>*)getQuickAuditAllIssuesSummaryForNode:(NSUUID *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];

    NSMutableArray<NSString*>* ret = NSMutableArray.array;

    if (flags.anyObject != nil) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_no_password_set", @"Audit: No password set")];
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_very_common_password", @"Audit: Password is very common")];
        }

        if ([flags containsObject:@(kAuditFlagPwned)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_pwned", @"Audit: Password is Pwned (HIBP)")];
        }

        if ([flags containsObject:@(kAuditFlagBreachedAccount)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_account_breached", @"Audit: Account Has Been Breached (HIBP)")];
        }

        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_duplicated_password", @"Audit: Password is duplicated in another entry")];
        }

        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_password_is_similar_to_another", @"Audit: Password is similar to one in another entry.")];
        }

        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_password_is_too_short", @"Audit: Password is too short.")];
        }

        if ([flags containsObject:@(kAuditFlagLowEntropy)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_password_low_entropy", @"Password is weak (low entropy)")];
        }

        if ([flags containsObject:@(kAuditFlagTwoFactorAvailable)]) {
            [ret addObject:NSLocalizedString(@"audit_quick_summary_two_factor_available", @"2 Factor Authentication is available for this domain.")];
        }
    }

    return ret;
}


- (NSString *)getQuickAuditSummaryForNode:(NSUUID *)item {
    NSSet<NSNumber*>* flags = [self getQuickAuditFlagsForNode:item];

    if (flags.anyObject != nil) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_no_password_set", @"Audit: No password set");
        }

        if ([flags containsObject:@(kAuditFlagBreachedAccount)]) {
            return NSLocalizedString(@"audit_quick_summary_very_brief_account_breached", @"Audit: Account Has Been Breached (HIBP)");
        }

        if ([flags containsObject:@(kAuditFlagPwned)]) {
            return NSLocalizedString(@"audit_quick_summary_pwned", @"Audit: Password is Pwned (HIBP)");
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_common_password", @"Audit: Password is very common");
        }

        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            return NSLocalizedString(@"audit_quick_summary_duplicated_password", @"Audit: Password is duplicated in another entry");
        }

        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_similar_to_another", @"Audit: Password is similar to one in another entry.");
        }

        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_too_short", @"Audit: Password is too short.");
        }

        if ([flags containsObject:@(kAuditFlagLowEntropy)]) {
            return NSLocalizedString(@"audit_quick_summary_password_low_entropy", @"Password is weak (low entropy)");
        }

        if ([flags containsObject:@(kAuditFlagTwoFactorAvailable)]) {
            return NSLocalizedString(@"audit_quick_summary_two_factor_available", @"2 Factor Authentication is available for this domain.");
        }
    }

    return @"";
}




- (NSSet<NSNumber *> *)getQuickAuditFlagsForNode:(NSUUID *)node {
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

    if ([self.mutablePwnedNodes containsObject:node]) {
        [ret addObject:@(kAuditFlagPwned)];
    }

    
    
    if (self.matchedBreachedDomainsByNode[node] && [self.matchedBreachedDomainsByNode[node] count] > 0) {
        [ret addObject:@(kAuditFlagBreachedAccount)];
    }

    if ([self.lowEntropy containsObject:node]) {
        [ret addObject:@(kAuditFlagLowEntropy)];
    }

    if ([self.twoFactorAvailable containsObject:node]) {
        [ret addObject:@(kAuditFlagTwoFactorAvailable)];
    }

    return ret;
}

- (NSUInteger)auditIssueNodeCount {
    NSMutableSet* set = [NSMutableSet setWithSet:self.noPasswords];

    [set addObjectsFromArray:self.commonPasswords.allObjects];
    [set addObjectsFromArray:self.duplicatedPasswordsNodeSet.allObjects];
    [set addObjectsFromArray:self.similarPasswordsNodeSet.allObjects];
    [set addObjectsFromArray:self.tooShort.allObjects];
    [set addObjectsFromArray:self.mutablePwnedNodes.arraySnapshot];
    [set addObjectsFromArray:self.mutableBreachedAccountNodes.arraySnapshot];
    [set addObjectsFromArray:self.lowEntropy.allObjects];
    [set addObjectsFromArray:self.twoFactorAvailable.allObjects];

    return set.count;
}

- (NSUInteger)auditIssueCount {
    return self.noPasswords.count +
    self.commonPasswords.count +
    self.duplicatedPasswordsNodeSet.count +
    self.similarPasswordsNodeSet.count +
    self.tooShort.count +
    self.mutablePwnedNodes.count +
    self.mutableBreachedAccountNodes.count +
    self.lowEntropy.count +
    self.twoFactorAvailable.count;
}

- (NSUInteger)haveIBeenPwnedErrorCount {
    return self.hibpErrorCount;
}

- (NSSet<NSUUID *> *)getSimilarPasswordNodeSet:(NSUUID *)node {
    if ([self.similarPasswordsNodeSet containsObject:node]) {
        NSArray<NSSet<NSUUID*>*>* containedInOthers = [self.similar.allValues filter:^BOOL(NSSet<NSUUID *> * _Nonnull obj) {
            return [obj containsObject:node];
        }];
        NSArray<NSUUID*>* allSimilarTo = [containedInOthers flatMap:^NSArray * _Nonnull(NSSet<NSUUID *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }];
        NSMutableSet* simSet = [NSMutableSet setWithArray:allSimilarTo];

        NSSet<NSUUID*>* directSimilars = self.similar[node];
        if (directSimilars) {
            [simSet addObjectsFromArray:directSimilars.allObjects];
        }
        [simSet removeObject:node];

        return simSet.copy;
    }
    else {
        return NSSet.set;
    }
}

- (NSSet<NSUUID *> *)getDuplicatedPasswordNodeSet:(NSUUID *)nodeId {
    if ([self.duplicatedPasswordsNodeSet containsObject:nodeId]) {
        NSArray<NSSet<NSUUID*>*>* containedInOthers = [self.duplicatedPasswords.allValues filter:^BOOL(NSSet<NSUUID *> * _Nonnull obj) {
            return [obj containsObject:nodeId];
        }];
        NSArray<NSUUID*>* allDuplicatesOf = [containedInOthers flatMap:^NSArray * _Nonnull(NSSet<NSUUID *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }];
        NSMutableSet* dupeSet = [NSMutableSet setWithArray:allDuplicatesOf];

        Node* node = [self.database getItemById:nodeId];
        if (node) {
            NSString* password = node.fields.password;
            NSSet<NSUUID*>* directDuplicates = self.duplicatedPasswords[password];
            if (directDuplicates) {
                [dupeSet addObjectsFromArray:directDuplicates.allObjects];
            }
        }
        [dupeSet removeObject:nodeId];

        return dupeSet.copy;
    }
    else {
        return NSSet.set;
    }
}




- (void)performAudits {
    self.noPasswords = [self checkForNoPasswords];

    self.duplicatedPasswords = [self checkForDuplicatedPasswords];
    self.duplicatedPasswordsNodeSet = [NSSet setWithArray:[self.duplicatedPasswords.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
        return obj.allObjects;
    }]];

    self.commonPasswords = [self checkForCommonPasswords];

    self.lowEntropy = [self checkForLowEntropy];

    self.tooShort = [self checkForTooShort];

    if (self.tooShort.anyObject || self.noPasswords.anyObject || self.duplicatedPasswordsNodeSet.anyObject || self.commonPasswords.anyObject) {
        self.nodesChanged();
    }

    if (self.isPro) {
        [self checkHibp];
    }

    if (self.isPro) {
        self.similar = [self checkForSimilarPasswords];
        self.similarPasswordsNodeSet = [NSSet setWithArray:[self.similar.allValues flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }]];
        if (self.similarPasswordsNodeSet.anyObject) {
            self.nodesChanged();
        }
    }

    self.twoFactorAvailable = [self checkForTwoFactorAvailable];
}

- (NSSet<NSUUID*>*)checkForTwoFactorAvailable {
    if (!self.config.checkForTwoFactorAvailable) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        if (obj.fields.otpToken) {
            return NO;
        }

        NSString* domain = [BrowserAutoFillManager extractPSLDomainFromUrlWithUrl:obj.fields.url];

        if (domain) {
            return [kTwoFactorDomains containsObject:domain];
        }
        else {
            return NO;
        }
    }];

    return [results map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
}

- (NSSet<NSUUID*>*)checkForNoPasswords {
    if (!self.config.checkForNoPasswords) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.database.allActiveEntries filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length == 0 && !self.isExcluded(obj);
    }];

    return [results map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
}

- (NSSet<NSUUID*>*)checkForTooShort {
    if (!self.config.checkForMinimumLength) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length < self.config.minimumLength;
    }];

    if (self.config.excludeShortNumericPINCodes) {
        results = [results filter:^BOOL(Node * _Nonnull obj) {
            return ![self isShortNumericOnlyPinCode:obj.fields.password];
        }];
    }

    return [results map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
}

- (BOOL)isShortNumericOnlyPinCode:(NSString*)password {
    return password.length <= 8 && password.isAllDigits;
}

- (NSDictionary<NSString*, NSSet<NSUUID*>*>*)checkForDuplicatedPasswords {
    if (!self.config.checkForDuplicatedPasswords) {
        return NSDictionary.dictionary;
    }

    NSMutableDictionary<NSString*, NSMutableSet<NSUUID*>*>* possibleDupes = NSMutableDictionary.dictionary;

    for (Node* entry in self.auditableNonEmptyPasswordNodes) {
        NSString* password = entry.fields.password;

        if (self.config.excludeShortNumericPINCodes && [self isShortNumericOnlyPinCode:password]) {
            continue;
        }

        if (self.config.caseInsensitiveMatchForDuplicates) {
            password = password.lowercaseString;
        }

        NSMutableSet<NSUUID*>* existing = possibleDupes[password];
        if (existing) {
            [existing addObject:entry.uuid];
        }
        else {
            possibleDupes[password] = [NSMutableSet setWithObject:entry.uuid];
        }
    }

    NSMutableDictionary<NSString*, NSSet<NSUUID*>*> *dupes = NSMutableDictionary.dictionary;
    for (NSString* password in possibleDupes.allKeys) {
        NSSet<NSUUID*>* nodes = possibleDupes[password];
        if (nodes.count > 1) {
            dupes[password] = nodes.copy;
        }
    }

    return dupes.copy;
}

- (NSSet<NSUUID*>*)checkForCommonPasswords {
    if (!self.config.checkForCommonPasswords) {
        return NSSet.set;
    }

    NSArray<Node*>* common = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        if (self.config.excludeShortNumericPINCodes && [self isShortNumericOnlyPinCode:obj.fields.password]) {
            return NO;
        }

        return [PasswordMaker.sharedInstance isCommonPassword:obj.fields.password];
    }];

    return [common map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
}

- (NSSet<NSUUID*>*)checkForLowEntropy {
    if (!self.config.checkForLowEntropy) {
        return NSSet.set;
    }

    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;

    NSArray<Node*>* lowEntropy = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        if (self.config.excludeShortNumericPINCodes && [self isShortNumericOnlyPinCode:obj.fields.password]) {
            return NO;
        }

        PasswordStrength* strength = [PasswordStrengthTester getStrength:obj.fields.password config:self.strengthConfig];
        BOOL low = strength.entropy < ((double)self.config.lowEntropyThreshold);
        return low;
    }];

    slog(@"LOW ENTROPY CHECK took [%f] seconds for %lu items", NSDate.timeIntervalSinceReferenceDate - startTime, (unsigned long)self.auditableNonEmptyPasswordNodes.count);

    return [lowEntropy map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        return obj.uuid;
    }].set;
}

- (NSDictionary<NSUUID*, NSSet<NSUUID*>*>*)checkForSimilarPasswords {
    if (!self.config.checkForSimilarPasswords) {
        return NSDictionary.dictionary;
    }

    NSMutableArray<Node*>* uncheckedOthers = self.auditableNonEmptyPasswordNodes.mutableCopy;
    NSMutableDictionary<NSUUID*, NSMutableSet<NSUUID*>*>* similarGroups = NSMutableDictionary.dictionary;

    int i = 0;
    int n = (int)self.auditableNonEmptyPasswordNodes.count - 1;
    int totalComparisons = (n * (n + 1)) / 2;

    slog(@"AUDIT: Similarity Comparisons required = %d", totalComparisons);
    for (Node* entry in self.auditableNonEmptyPasswordNodes) {
        NSString* password = entry.fields.password;
        [uncheckedOthers removeObject:entry];

        if (self.config.excludeShortNumericPINCodes && [self isShortNumericOnlyPinCode:password]) {
            continue;
        }

        for (Node* other in uncheckedOthers) {
            if (i % 1000 == 0) {
                self.similarProgress = (CGFloat)i/(CGFloat)totalComparisons;
                [self publishPartialProgress];
            }
            i++;

            if (self.stopRequested) {
                self.state = kAuditStateStoppedIncomplete;
                return similarGroups.copy;
            }

            NSString* otherPassword = other.fields.password;

            if ([password compare:otherPassword] == NSOrderedSame) {
                continue;
            }

            double similarity = [password levenshteinSimilarityRatio:otherPassword];

            if (similarity >= self.config.levenshteinSimilarityThreshold) {
                NSMutableSet<NSUUID*>* existingGroup = similarGroups[entry.uuid];

                if (existingGroup == nil) {
                    for (NSUUID* groupKey in similarGroups.allKeys) {
                        NSMutableSet<NSUUID*>* group = similarGroups[groupKey];
                        if ([group containsObject:other.uuid] || [group containsObject:entry.uuid]) {
                            existingGroup = group;
                        }
                    }
                }

                if (existingGroup == nil) {
                    similarGroups[entry.uuid] = [NSMutableSet set];
                    existingGroup = similarGroups[entry.uuid];
                }

                [existingGroup addObject:entry.uuid];
                [existingGroup addObject:other.uuid];
            }
        }
    }

    return similarGroups.copy;
}

#pragma mark - HIBP Account Breach Check (with Domain Matching)


- (NSString *)normalizeDomain:(NSString *)domain {
    NSString *lowercased = [domain lowercaseString];
    if ([lowercased hasPrefix:@"http:
        NSURL *url = [NSURL URLWithString:lowercased];
        if (url.host) {
            lowercased = url.host;
        }
    }
    if ([lowercased hasPrefix:@"www."]) {
        lowercased = [lowercased substringFromIndex:4];
    }
    return lowercased;
}


- (BOOL)looseDomainMatch:(NSString *)domain1 withDomain:(NSString *)domain2 {
    return [[self normalizeDomain:domain1] isEqualToString:[self normalizeDomain:domain2]];
}

- (void)checkHibp {
    [SecretStore.sharedInstance deleteSecureItem:kSecretStoreBreachedAccountsCacheKey];

    slog(@"AUDIT: HIBP: Checking HaveIBeenPwned...");

    if (!self.config.checkHibp) {
        return;
    }

    NSArray<Node*>* filtered = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        if (self.config.excludeShortNumericPINCodes && [self isShortNumericOnlyPinCode:obj.fields.password]) {
            return NO;
        }
        return YES;
    }];

    
    NSDictionary<NSString*, NSArray<Node*>*> *nodesByEmails = [filtered groupBy:^id _Nonnull(Node * _Nonnull obj) {
        return obj.fields.username;
    }];

    
    self.hibpQueue.suspended = YES;
    self.hibpTotalCount = nodesByEmails.allKeys.count + 0;
    self.hibpCompletedCount = 0;

    
    BOOL checkForNewBreaches = self.config.checkHibpBreaches;

    NSDate *lastChecked = self.config.lastHibpOnlineCheck;
    if (checkForNewBreaches && lastChecked && self.config.hibpCheckForNewBreachesIntervalSeconds > 0) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *dueDate = [cal dateByAddingUnit:NSCalendarUnitSecond value:self.config.hibpCheckForNewBreachesIntervalSeconds toDate:lastChecked options:0];
        checkForNewBreaches = dueDate.timeIntervalSinceNow < 0;
        slog(@"Due Date for New Breaches: [%@]", dueDate);
    }

    if (checkForNewBreaches) {
        slog(@"Will Check for New Breaches....");
        self.config.lastHibpOnlineCheck = NSDate.date;

        if (self.saveConfig) {
            self.saveConfig(self.config);
        }
    }

    slog(@"HIBP: Nodes to check (by email): %lu", (unsigned long)nodesByEmails.allKeys.count);

    
    
    NSMutableDictionary *breachedAccountsCache = [[SecretStore.sharedInstance getSecureObject:kSecretStoreBreachedAccountsCacheKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    for (NSString* email in nodesByEmails.allKeys) {
        NSArray<Node*>* affectedNodes = nodesByEmails[email];

        if (breachedAccountsCache[email]) {
            NSDictionary *breachInfo = breachedAccountsCache[email];
            NSArray *allBreaches = breachInfo[@"allBreaches"];
            slog(@"HIBP: Cache HIT ACCOUNT for email: [%@]", email);

            
            for (Node* node in affectedNodes) {
                NSString *nodeDomain = [BrowserAutoFillManager extractPSLDomainFromUrlWithUrl:node.fields.url];
                if (nodeDomain.length) {
                    NSMutableArray *matchedBreaches = [NSMutableArray array];
                    for (NSString *breachDomain in allBreaches) {
                        if ([self looseDomainMatch:nodeDomain withDomain:breachDomain]) {
                            [matchedBreaches addObject:breachDomain];
                        }
                    }
                    if (matchedBreaches.count > 0) {
                        [self.mutableBreachedAccountNodes addObject:node.uuid];
                        self.matchedBreachedDomainsByNode[node.uuid] = [matchedBreaches copy];
                    }
                }
            }
            self.hibpCompletedCount += 1;
        }
        else {
            
            UrlRequestOperation* op = [self checkAccountBreached:email nodes:affectedNodes];
            [self.hibpQueue addOperation:op];
        }
    }

    if (self.hibpCompletedCount) {
        self.hibpProgress = ((CGFloat)self.hibpCompletedCount / self.hibpTotalCount);
        [self publishPartialProgress];
        self.nodesChanged();
    }

    self.hibpQueue.suspended = NO;
    [self.hibpQueue waitUntilAllOperationsAreFinished];

    if (self.stopRequested) {
        self.state = kAuditStateStoppedIncomplete;
    }
}

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion {
    NSString* sha1HexPassword = password.sha1Data.upperHexString;
    NSSet<NSString*>* pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];

    if ([pwnedCache containsObject:sha1HexPassword]) {
        completion(YES, nil);
    }
    else  {
        NSMutableURLRequest *request = [self getHibpUrlRequest:sha1HexPassword];

        UrlRequestOperation* op = [[UrlRequestOperation alloc] initWithRequest:request.copy
                                                       dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                slog(@"ERROR: [%@]", error);
                completion(NO, error);
                return;
            }

            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

            if (httpResponse.statusCode == kHttpStatusOk) {
                BOOL found = [self processHibpResponse:data targetHash:sha1HexPassword];

                if (found) {
                    NSSet<NSString*> *pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];
                    slog(@"Caching HIBP hit...");
                    NSMutableSet<NSString*>* mut = pwnedCache ? pwnedCache.mutableCopy : NSMutableSet.set;
                    [mut addObject:sha1HexPassword];
                    [SecretStore.sharedInstance setSecureObject:mut.copy forIdentifier:kSecretStoreHibpPwnedSetCacheKey];
                }

                completion(found, nil);
            }
            else {
                slog(@"HTTP [%ld] - [%@]", (long)httpResponse.statusCode , error);
                completion(NO, [Utils createNSError:[NSString stringWithFormat:@"response = [%@]", httpResponse] errorCode:-2345]);
            }
        }];

        [self.hibpQueue addOperation:op];
        self.hibpQueue.suspended = NO;
    }
}

- (NSMutableURLRequest*)getHibpUrlRequest:(NSString*)sha1HexPassword {
    NSURL* url = [self buildHibpUrl:sha1HexPassword];
    const NSTimeInterval kUrlRequestTimeout = 5.0f;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kUrlRequestTimeout];
    [request addValue:@"true" forHTTPHeaderField:@"Add-Padding"];
    return request;
}

- (NSMutableURLRequest*)getHibpAccountUrlRequest:(NSString*)email {
    NSURL* url = [self buildHibpAccountUrl];
    const NSTimeInterval kUrlRequestTimeout = 5.0f;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:kUrlRequestTimeout];
    NSMutableDictionary *payload = [@{
        @"account": email,
        @"device_token": self.deviceCheckToken ?: @"",
        @"bundle_id": [NSBundle.mainBundle bundleIdentifier] ?: @""
    } mutableCopy];

#if DEBUG
    payload[@"dev"] = @YES;
#else
    payload[@"dev"] = @NO;
#endif

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!jsonError && jsonData) {
        request.HTTPBody = jsonData;
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    } else {
        NSLog(@"JSON Error while encoding payload: %@", jsonError);
    }

    request.HTTPMethod = @"POST";

    return request;
}

- (UrlRequestOperation*)haveIBeenPwned:(NSString*)password sha1HexPassword:(NSString*)sha1HexPassword nodes:(NSArray<Node*>*)nodes {
    NSMutableURLRequest *request = [self getHibpUrlRequest:sha1HexPassword];

    return [[UrlRequestOperation alloc] initWithRequest:request.copy dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self handleUrlRequestCompletion:password sha1HexPassword:sha1HexPassword nodes:nodes data:data response:response error:error];
    }];
}

- (UrlRequestOperation*)checkAccountBreached:(NSString*)email nodes:(NSArray<Node*>*)nodes {
    NSMutableURLRequest *request = [self getHibpAccountUrlRequest:email];
    slog(@"🔎 HIBP Account Check - Email: [%@]", email);
    slog(@"🔎 HIBP Account Check - Request URL: [%@]", request.URL);
    slog(@"🔎 HIBP Account Check - Request Headers: [%@]", request.allHTTPHeaderFields);

    return [[UrlRequestOperation alloc] initWithRequest:request.copy dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self handleAccountCheckCompletion:email nodes:nodes data:data response:response error:error];
    }];
}

- (void)handleUrlRequestCompletion:(NSString*)password
                   sha1HexPassword:(NSString*)sha1HexPassword
                             nodes:(NSArray<Node*>*)nodes
                              data:(NSData*)data
                          response:(NSURLResponse*)response
                             error:(NSError*)error {
    self.hibpCompletedCount++;

    if (self.hibpCompletedCount % 10 == 0) {
        self.hibpProgress = ((CGFloat)self.hibpCompletedCount / self.hibpTotalCount);
        [self publishPartialProgress];
    }

    if (error) {
        self.hibpErrorCount++;
        slog(@"ERROR: [%@]", error);
        return;
    }

    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;

    if (httpResponse.statusCode == kHttpStatusOk) {
        BOOL found = [self processHibpResponse:data targetHash:sha1HexPassword];

        if (found) {
            NSSet<NSString*> *pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];
            slog(@"Caching HIBP hit...");
            NSMutableSet<NSString*>* mut = pwnedCache ? pwnedCache.mutableCopy : NSMutableSet.set;
            [mut addObject:sha1HexPassword];
            [SecretStore.sharedInstance setSecureObject:mut.copy forIdentifier:kSecretStoreHibpPwnedSetCacheKey];

            NSArray<NSUUID*> *ids = [nodes map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
                return obj.uuid;
            }];
            [self.mutablePwnedNodes addObjectsFromArray:ids];
            self.nodesChanged();
        }
    }
    else {
        slog(@"HTTP [%ld] - [%@]", (long)httpResponse.statusCode , error);
        self.hibpErrorCount++;
    }
}

- (NSURL*)buildHibpUrl:(NSString*)sha1HexPassword {
    NSString* prefix = [sha1HexPassword substringToIndex:5];
    NSURLComponents* components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = @"api.pwnedpasswords.com";
    components.path = [NSString stringWithFormat:@"/range/%@", prefix];
    NSURL* url = components.URL;
    return url;
}

- (NSURL *)buildHibpAccountUrl {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = @"faas-nyc1-2ef2e6cc.doserverless.co";
    components.path = @"/api/v1/web/fn-8a419571-d5b5-47d2-852f-a153c3e81553/strongbox-mirror-one/pwned";
    return components.URL;
}

- (void)handleAccountCheckCompletion:(NSString*)email
                              nodes:(NSArray<Node*>*)nodes
                               data:(NSData*)data
                           response:(NSURLResponse*)response
                              error:(NSError*)error {
    self.hibpCompletedCount++;
    slog(@"🔍 HIBP Account Check - Handling response for email: [%@]", email);

    if (self.hibpCompletedCount % 10 == 0) {
        self.hibpProgress = ((CGFloat)self.hibpCompletedCount / self.hibpTotalCount);
        [self publishPartialProgress];
    }

    if (error) {
        self.hibpErrorCount++;
        slog(@"❌ HIBP Account Check - ERROR: [%@]", error);
        return;
    }

    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    slog(@"🔍 HIBP Account Check - Response Status Code: [%d]", (int)httpResponse.statusCode);
    slog(@"🔍 HIBP Account Check - Response Headers: [%@]", httpResponse.allHeaderFields);

    if (httpResponse.statusCode == kHttpStatusOk) {
        NSError *jsonError = nil;
        NSArray *breachedSites = nil;

        if (data) {
            NSString *rawResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            slog(@"🔍 HIBP Account Check - Raw Response: [%@]", rawResponse);
            breachedSites = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        } else {
            slog(@"🔍 HIBP Account Check - No response data received");
        }

        if (jsonError) {
            slog(@"❌ HIBP Account Check - Failed to parse JSON: %@", jsonError);
            self.hibpErrorCount++;
            return;
        }

        NSMutableArray<NSString*> *allBreaches = [NSMutableArray array];
        for (NSDictionary *breach in breachedSites) {
            NSString *domain = breach[@"Domain"];
            if (domain) {
                [allBreaches addObject:domain];
                slog(@"Found breach for email [%@] in site [%@]", email, domain);
            }
        }

        
        NSMutableDictionary *breachedAccountsCache = [[SecretStore.sharedInstance getSecureObject:kSecretStoreBreachedAccountsCacheKey] mutableCopy] ?: [NSMutableDictionary dictionary];
        NSDictionary *breachInfo = @{ @"allBreaches": allBreaches.copy };
        slog(@"Caching HIBP account breach hit for [%@]... Found breaches: %@", email, allBreaches);
        breachedAccountsCache[email] = breachInfo;
        [SecretStore.sharedInstance setSecureObject:breachedAccountsCache.copy forIdentifier:kSecretStoreBreachedAccountsCacheKey];

        
        for (Node* node in nodes) {
            NSString *nodeDomain = [BrowserAutoFillManager extractPSLDomainFromUrlWithUrl:node.fields.url];
            if (nodeDomain.length) {
                NSMutableArray *matchedBreaches = [NSMutableArray array];
                for (NSString *breachDomain in allBreaches) {
                    if ([self looseDomainMatch:nodeDomain withDomain:breachDomain]) {
                        [matchedBreaches addObject:breachDomain];
                    }
                }
                if (matchedBreaches.count > 0) {
                    [self.mutableBreachedAccountNodes addObject:node.uuid];
                    self.matchedBreachedDomainsByNode[node.uuid] = [matchedBreaches copy];
                }
            }
        }
        self.nodesChanged();
    }
    else if (httpResponse.statusCode == kHttpStatusNotFound) {
        slog(@"✅ HIBP Account Check - No breaches found for email: [%@] (Status 404)", email);
    }
    else {
        slog(@"❌ HIBP Account Check - Unexpected status code: [%ld] - Error: [%@]", (long)httpResponse.statusCode, error);
        if (data) {
            NSString *rawResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            slog(@"❌ HIBP Account Check - Error response body: [%@]", rawResponse);
        }
        self.hibpErrorCount++;
    }
}

- (void)oneTimeAccountBreachCheck:(NSString*)email completion:(void(^)(BOOL breached, NSArray<NSString*>* _Nullable breachedSites, NSError* _Nullable error))completion {
    slog(@"🔎 HIBP One-Time Account Check - Starting for email: [%@]", email);
    
    NSDictionary<NSString*, NSDictionary*>* breachedAccountsCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreBreachedAccountsCacheKey];

    if (breachedAccountsCache[email]) {
        slog(@"🔎 HIBP One-Time Account Check - Cache HIT for email: [%@]", email);
        NSDictionary *breachInfo = breachedAccountsCache[email];
        completion(YES, breachInfo[@"allBreaches"], nil);
    }
    else {
        slog(@"🔎 HIBP One-Time Account Check - Cache MISS for email: [%@], checking API", email);
        NSMutableURLRequest *request = [self getHibpAccountUrlRequest:email];

        slog(@"🔎 HIBP One-Time Account Check - Request URL: [%@]", request.URL);
        slog(@"🔎 HIBP One-Time Account Check - Request Headers: [%@]", request.allHTTPHeaderFields);

        UrlRequestOperation* op = [[UrlRequestOperation alloc] initWithRequest:request.copy
                                                       dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                slog(@"❌ HIBP One-Time Account Check - ERROR: [%@]", error);
                completion(NO, nil, error);
                return;
            }

            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            slog(@"🔍 HIBP One-Time Account Check - Response status code: [%d]", (int)httpResponse.statusCode);
            slog(@"🔍 HIBP One-Time Account Check - Response headers: [%@]", httpResponse.allHeaderFields);

            if (httpResponse.statusCode == kHttpStatusOk) {
                NSError *jsonError = nil;
                NSArray *breachedSites = nil;

                if (data) {
                    NSString *rawResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    slog(@"🔍 HIBP One-Time Account Check - Raw response: [%@]", rawResponse);
                    breachedSites = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                }
                else {
                    slog(@"🔍 HIBP One-Time Account Check - No response data received");
                }

                if (jsonError) {
                    slog(@"❌ HIBP One-Time Account Check - Failed to parse JSON: %@", jsonError);
                    completion(NO, nil, jsonError);
                    return;
                }

                NSMutableArray<NSString*> *allBreaches = [NSMutableArray array];
                for (NSDictionary *breach in breachedSites) {
                    NSString *domain = breach[@"Domain"];
                    if (domain) {
                        [allBreaches addObject:domain];
                        slog(@"🔍 HIBP One-Time Account Check - Found breach site: [%@]", domain);
                    }
                    else {
                        slog(@"⚠️ HIBP One-Time Account Check - Found breach without Domain field: [%@]", breach);
                    }
                }

                
                NSMutableDictionary *breachedAccountsCache = [[SecretStore.sharedInstance getSecureObject:kSecretStoreBreachedAccountsCacheKey] mutableCopy] ?: [NSMutableDictionary dictionary];
                NSDictionary *breachInfo = @{ @"allBreaches": allBreaches.copy };
                slog(@"✅ HIBP One-Time Account Check - Caching breach hit for [%@] with [%lu] sites", email, (unsigned long)allBreaches.count);
                breachedAccountsCache[email] = breachInfo;
                [SecretStore.sharedInstance setSecureObject:breachedAccountsCache.copy forIdentifier:kSecretStoreBreachedAccountsCacheKey];

                completion(YES, allBreaches.copy, nil);
            }
            else if (httpResponse.statusCode == kHttpStatusNotFound) {
                slog(@"✅ HIBP One-Time Account Check - No breaches found for [%@] (404)", email);
                completion(NO, nil, nil);
            }
            else {
                slog(@"❌ HIBP One-Time Account Check - Unexpected status: [%ld]", (long)httpResponse.statusCode);
                if (data) {
                    NSString *errorBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    slog(@"❌ HIBP One-Time Account Check - Error response: [%@]", errorBody);
                }
                completion(NO, nil, [Utils createNSError:[NSString stringWithFormat:@"response = [%@]", httpResponse] errorCode:-2345]);
            }
        }];

        [self.hibpQueue addOperation:op];
        self.hibpQueue.suspended = NO;
    }
}

- (BOOL)processHibpResponse:(NSData*)data targetHash:(NSString*)targetHash {
    NSString* suffix = [targetHash substringFromIndex:5];
    NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSArray<NSString*>* trimmed = [str.lines map:^id _Nonnull(NSString * _Nonnull obj, NSUInteger idx) {
        return obj.trimmed;
    }];

    NSArray<NSString*> *nonEmpty = [trimmed filter:^BOOL(NSString * _Nonnull obj) {
        return obj.length != 0;
    }];

    for (NSString* line in nonEmpty) {
        NSArray<NSString*>* components = [line componentsSeparatedByString:@":"];
        if (components.count != 2) {
            return NO;
        }

        NSString* hash = components[0];
        NSString* count = components[1];

        if (![count isEqualToString:@"0"] && [hash isEqualToString:suffix]) {
            return YES;
        }
    }

    return NO;
}

- (CGFloat)calculatedProgress {
    const CGFloat hibp = 0.8;
    const CGFloat sim = 1.0 - hibp;

    CGFloat hibpWeight = self.config.checkHibp ? (self.config.checkForSimilarPasswords ? hibp : 1.0) : 0;
    CGFloat similarWeight = self.config.checkForSimilarPasswords ? (self.config.checkHibp ? sim : 1.0) : 0;

    CGFloat calculatedProgress = (self.hibpProgress * hibpWeight) + (self.similarProgress * similarWeight);

    return calculatedProgress;
}

- (void)publishPartialProgress {
    self.progress(self.calculatedProgress);
}

- (void)fetchAndStoreDeviceCheckToken {
    #if TARGET_OS_OSX
    if([Settings.sharedInstance disableNetworkBasedFeatures]) {
        return;
    }
    #else
    if ([[AppPreferences sharedInstance] disableNetworkBasedFeatures]) {
        return;
    }
    #endif

    DCDevice *device = [DCDevice currentDevice];
    if (![device isSupported]) {
        NSLog(@"DeviceCheck is not supported on this device.");
        return;
    }

    [device generateTokenWithCompletionHandler:^(NSData * _Nullable tokenData, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error generating DeviceCheck token: %@", error);
            return;
        }

        if (tokenData) {
            NSString *tokenString = [tokenData base64EncodedStringWithOptions:0];
            self.deviceCheckToken = tokenString;
            NSLog(@"DeviceCheck token generated: %@", tokenString);
        }
    }];
}

@end
