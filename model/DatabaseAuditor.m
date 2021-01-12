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
#import "NSData+Extensions.h"
#import "NSString+Extensions.h"
#import "ConcurrentMutableSet.h"
#import "UrlRequestOperation.h"
#import "SecretStore.h"
#import "Utils.h"

static const int kHttpStatusOk = 200;
static NSString* const kSecretStoreHibpPwnedSetCacheKey = @"SecretStoreHibpPwnedSetCacheKey";

@interface DatabaseAuditor ()

@property AuditIsDereferenceableTextBlock isDereferenceable;

@property AuditProgressBlock progress;
@property AuditCompletionBlock completion;
@property AuditNodesChangedBlock nodesChanged;

@property BOOL stopRequested;
@property DatabaseAuditorConfiguration* config;



@property NSSet<Node*>* commonPasswords;
@property NSDictionary<NSString*, NSSet<Node*>*>* duplicatedPasswords;
@property NSSet<Node*>* noPasswords;
@property NSDictionary<NSUUID*, NSSet<Node*>*>* similar;
@property NSSet<Node*>* tooShort;

@property NSSet<Node*>* duplicatedPasswordsNodeSet; 
@property NSSet<Node*>* similarPasswordsNodeSet; 

@property BOOL isPro;

@property ConcurrentMutableSet<Node*>* mutablePwnedNodes;
@property NSOperationQueue *hibpQueue;

@property NSUInteger hibpErrorCount;
@property NSUInteger hibpCompletedCount;
@property NSUInteger hibpTotalCount;

@property CGFloat hibpProgress;
@property CGFloat similarProgress;

@property NSSet<Node*>* nodes;
@property NSArray<Node*>* auditableNonEmptyPasswordNodes;

@property (nullable) SaveConfigurationBlock saveConfig;
@property (nullable) IsExcludedBlock isExcluded;

@end

@implementation DatabaseAuditor

- (instancetype)initWithPro:(BOOL)pro {
    return [self initWithPro:pro isExcluded:nil saveConfig:nil];
}

- (instancetype)initWithPro:(BOOL)pro isExcluded:(IsExcludedBlock)isExcluded saveConfig:(SaveConfigurationBlock)saveConfig {
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
     
        self.hibpQueue = [NSOperationQueue new];
        self.hibpQueue.maxConcurrentOperationCount = 4;
        self.mutablePwnedNodes = ConcurrentMutableSet.mutableSet;
        
        self.isExcluded = (isExcluded != nil) ? isExcluded : ^BOOL(Node * _Nonnull item) {
            return NO;
        };
        self.saveConfig = saveConfig;
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
    self.config = config;

    self.nodes = nodes.copy;
    self.auditableNonEmptyPasswordNodes = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length && !self.isDereferenceable(obj.fields.password) && !self.isExcluded(obj);
    }];

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

    if (self.state == kAuditStateRunning) { 
        self.state = kAuditStateDone;
    }
    
    self.completion(self.state == kAuditStateStoppedIncomplete);
}

- (void)stop {
    NSLog(@"AUDIT: Stopping Audit...");
    self.stopRequested = YES;
    [self.hibpQueue cancelAllOperations];
}

- (DatabaseAuditReport *)getAuditReport {
    DatabaseAuditReport* report = [[DatabaseAuditReport alloc] initWithNoPasswordEntries:self.noPasswords
                                                                     duplicatedPasswords:self.duplicatedPasswords
                                                                         commonPasswords:self.commonPasswords
                                                                                 similar:self.similar
                                                                                tooShort:self.tooShort
                                                                                   pwned:self.mutablePwnedNodes.snapshot];
    
    return report;
}




- (NSString *)getQuickAuditVeryBriefSummaryForNode:(Node *)item {
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
    
    if (flags.anyObject != nil) {
        if ([flags containsObject:@(kAuditFlagNoPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_no_password_set", @"Audit: No password set");
        }

        if ([flags containsObject:@(kAuditFlagCommonPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_very_common_password", @"Audit: Password is very common");
        }
        
        if ([flags containsObject:@(kAuditFlagPwned)]) {
            return NSLocalizedString(@"audit_quick_summary_pwned", @"Audit: Password is Pwned (HIBP)");
        }
        
        if ([flags containsObject:@(kAuditFlagDuplicatePassword)]) {
            return NSLocalizedString(@"audit_quick_summary_duplicated_password", @"Audit: Password is duplicated in another entry");
        }
        
        if ([flags containsObject:@(kAuditFlagSimilarPassword)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_similar_to_another", @"Audit: Password is similar to one in another entry.=");
        }
        
        if ([flags containsObject:@(kAuditFlagTooShort)]) {
            return NSLocalizedString(@"audit_quick_summary_password_is_too_short", @"Audit: Password is too short.");
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

    if ([self.mutablePwnedNodes containsObject:node]) {
        [ret addObject:@(kAuditFlagPwned)];
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
    
    return set.count;
}

- (NSUInteger)auditIssueCount {
    return  self.noPasswords.count +
            self.commonPasswords.count +
            self.duplicatedPasswordsNodeSet.count +
            self.similarPasswordsNodeSet.count +
            self.tooShort.count +
            self.mutablePwnedNodes.count;
}

- (NSUInteger)haveIBeenPwnedErrorCount {
    return self.hibpErrorCount;
}

- (NSSet<Node*>*)getSimilarPasswordNodeSet:(Node*)node {
    if ([self.similarPasswordsNodeSet containsObject:node]) {
        
        
        
        NSArray<NSSet<Node*>*>* containedInOthers = [self.similar.allValues filter:^BOOL(NSSet<Node *> * _Nonnull obj) {
            return [obj containsObject:node];
        }];
        
        NSArray<Node*>* allSimilarTo = [containedInOthers flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }];
        
        NSMutableSet* simSet = [NSMutableSet setWithArray:allSimilarTo];

        
        
        NSSet<Node*>* directSimilars = self.similar[node.uuid];
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

- (NSSet<Node*>*)getDuplicatedPasswordNodeSet:(Node*)node {
    if ([self.duplicatedPasswordsNodeSet containsObject:node]) {
        
        
        
        NSArray<NSSet<Node*>*>* containedInOthers = [self.duplicatedPasswords.allValues filter:^BOOL(NSSet<Node *> * _Nonnull obj) {
            return [obj containsObject:node];
        }];
        
        NSArray<Node*>* allDuplicatesOf = [containedInOthers flatMap:^NSArray * _Nonnull(NSSet<Node *> * _Nonnull obj, NSUInteger idx) {
            return obj.allObjects;
        }];
        
        NSMutableSet* dupeSet = [NSMutableSet setWithArray:allDuplicatesOf];

        
        
        NSSet<Node*>* directDuplicates = self.duplicatedPasswords[node.fields.password];
        if (directDuplicates) {
            [dupeSet addObjectsFromArray:directDuplicates.allObjects];
        }
        
        
        
        [dupeSet removeObject:node];
        
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

    
    
    
}

- (NSSet<Node*>*)checkForNoPasswords {
    if (!self.config.checkForNoPasswords) {
        return NSSet.set;
    }

    NSArray<Node*>* results = [self.nodes.allObjects filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length == 0 && !self.isExcluded(obj);
    }];

    return [NSSet setWithArray:results];
}

- (NSSet<Node*>*)checkForTooShort {
    if (!self.config.checkForMinimumLength) {
        return NSSet.set;
    }
    
    NSArray<Node*>* results = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        return obj.fields.password.length < self.config.minimumLength; 
    }];

    return [NSSet setWithArray:results];
}

- (NSDictionary<NSString*, NSSet<Node*>*>*)checkForDuplicatedPasswords {
    if (!self.config.checkForDuplicatedPasswords) {
        return NSDictionary.dictionary;
    }
    
    NSMutableDictionary<NSString*, NSMutableSet<Node*>*>* possibleDupes = NSMutableDictionary.dictionary;
    
    for (Node* entry in self.auditableNonEmptyPasswordNodes) {
        
        NSString* password = entry.fields.password;
        
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

    NSArray<Node*>* common = [self.auditableNonEmptyPasswordNodes filter:^BOOL(Node * _Nonnull obj) {
        return [PasswordMaker.sharedInstance isCommonPassword:obj.fields.password];
    }];
    
    return [NSSet setWithArray:common];
}

- (NSDictionary<NSUUID*, NSSet<Node*>*>*)checkForSimilarPasswords {
    if (!self.config.checkForSimilarPasswords) {
        return NSDictionary.dictionary;
    }
    
    NSMutableArray<Node*>* uncheckedOthers = self.auditableNonEmptyPasswordNodes.mutableCopy; 

    NSMutableDictionary<NSUUID*, NSMutableSet<Node*>*>* similarGroups = NSMutableDictionary.dictionary;
    
    int i=0;
    int n = (int)self.auditableNonEmptyPasswordNodes.count - 1;
    int totalComparisons = (n * (n + 1)) / 2; 
    
    NSLog(@"AUDIT: Similarity Comparisons required = %d", totalComparisons);
    for (Node* entry in self.auditableNonEmptyPasswordNodes) {
        NSString* password = entry.fields.password;

        [uncheckedOthers removeObject:entry];

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
                

                if(!similarGroups[entry.uuid]) {
                    similarGroups[entry.uuid] = [NSMutableSet setWithObject:entry];
                }
                
                [similarGroups[entry.uuid] addObject:other];
            }
        }
    }
    
    return similarGroups.copy;
}

- (void)checkHibp {
    NSLog(@"AUDIT: Checking HaveIBeenPwned...");

    if(!self.config.showCachedHibpHits && !self.config.checkHibp) {
        
        return;
    }
    
    NSDictionary<NSString*, NSArray<Node*>*> *nodesByPasswords = [self.auditableNonEmptyPasswordNodes groupBy:^id _Nonnull(Node * _Nonnull obj) {
        return obj.fields.password;
    }];
    
    self.hibpQueue.suspended = YES;
    self.hibpTotalCount = nodesByPasswords.allKeys.count;
    self.hibpCompletedCount = 0;

    BOOL checkForNewBreaches = self.config.checkHibp;

    NSDate *lastChecked = self.config.lastHibpOnlineCheck;
    NSLog(@"Last Checked for New Breaches: [%@]", lastChecked);
    if (checkForNewBreaches && lastChecked && self.config.hibpCheckForNewBreachesIntervalSeconds > 0) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *dueDate = [cal dateByAddingUnit:NSCalendarUnitSecond value:self.config.hibpCheckForNewBreachesIntervalSeconds toDate:lastChecked options:0];
        checkForNewBreaches = dueDate.timeIntervalSinceNow < 0;
        NSLog(@"Due Date for New Breaches: [%@]", dueDate);
    }
    
    if (checkForNewBreaches) {
        NSLog(@"Will Check for New Breaches....");
        self.config.lastHibpOnlineCheck = NSDate.date;
        
        if (self.saveConfig) {
            self.saveConfig(self.config);
        }
    }
    else {
        NSLog(@"Will NOT check for new breaches, due to config or last check to recent.");
    }
    
    NSSet<NSString*>* pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];
    
    for (NSString* password in nodesByPasswords.allKeys) {
        NSString* sha1HexPassword = password.sha1Data.hexString;
        NSArray<Node*>* affectedNodes = nodesByPasswords[password];
        
        if ([pwnedCache containsObject:sha1HexPassword]) {
            NSLog(@"Pwned: Cache HIT!");
            self.hibpCompletedCount++;
            [self.mutablePwnedNodes addObjectsFromArray:affectedNodes];
        }
        else if (checkForNewBreaches) {
            UrlRequestOperation* op = [self haveIBeenPwned:password sha1HexPassword:sha1HexPassword nodes:affectedNodes];
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
    
    NSLog(@"AUDIT: HaveIBeenPwned... Done!");
}

- (void)oneTimeHibpCheck:(NSString*)password completion:(void(^)(BOOL pwned, NSError* error))completion {
    NSString* sha1HexPassword = password.sha1Data.hexString;
    NSSet<NSString*>* pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];
    
    if ([pwnedCache containsObject:sha1HexPassword]) {
        NSLog(@"Pwned: Cache HIT!");
        completion(YES, nil);
    }
    else  {
          NSMutableURLRequest *request = [self getHibpUrlRequest:sha1HexPassword];

          UrlRequestOperation* op = [[UrlRequestOperation alloc] initWithRequest:request.copy dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
              if (error) {
                  NSLog(@"ERROR: [%@]", error);
                  completion(NO, error);
                  return;
              }
              
              NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
              
              if (httpResponse.statusCode == kHttpStatusOk) {
                  BOOL found = [self processHibpResponse:data targetHash:sha1HexPassword];
                   
                  if (found) {
                      NSSet<NSString*> *pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];
                      NSLog(@"Caching HIBP hit...");
                      NSMutableSet<NSString*>* mut = pwnedCache ? pwnedCache.mutableCopy : NSMutableSet.set;
                      [mut addObject:sha1HexPassword];
                      [SecretStore.sharedInstance setSecureObject:mut.copy forIdentifier:kSecretStoreHibpPwnedSetCacheKey];
                  }
                  
                  completion(found, nil);
              }
              else {
                  NSLog(@"HTTP [%ld] - [%@]", (long)httpResponse.statusCode , error);
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

- (UrlRequestOperation*)haveIBeenPwned:(NSString*)password sha1HexPassword:(NSString*)sha1HexPassword nodes:(NSArray<Node*>*)nodes {
    NSMutableURLRequest *request = [self getHibpUrlRequest:sha1HexPassword];
    
    return [[UrlRequestOperation alloc] initWithRequest:request.copy dataTaskCompletionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [self handleUrlRequestCompletion:password sha1HexPassword:sha1HexPassword nodes:nodes data:data response:response error:error];
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
        NSLog(@"ERROR: [%@]", error);
        return;
    }
    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    
    if (httpResponse.statusCode == kHttpStatusOk) {
        BOOL found = [self processHibpResponse:data targetHash:sha1HexPassword];
         
        if (found) {
            NSSet<NSString*> *pwnedCache = [SecretStore.sharedInstance getSecureObject:kSecretStoreHibpPwnedSetCacheKey];

            NSLog(@"Caching HIBP hit...");
            NSMutableSet<NSString*>* mut = pwnedCache ? pwnedCache.mutableCopy : NSMutableSet.set;
            
            [mut addObject:sha1HexPassword];
            [SecretStore.sharedInstance setSecureObject:mut.copy forIdentifier:kSecretStoreHibpPwnedSetCacheKey];
            
            [self.mutablePwnedNodes addObjectsFromArray:nodes];
            self.nodesChanged();
        }
    }
    else {
        NSLog(@"HTTP [%ld] - [%@]", (long)httpResponse.statusCode , error);
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

- (void)publishPartialProgress {
    const CGFloat hibp = 0.8; 
    const CGFloat sim = 1.0 - hibp;
    
    CGFloat hibpWeight = self.config.checkHibp ? (self.config.checkForSimilarPasswords ? hibp : 1.0) : 0;
    CGFloat similarWeight = self.config.checkForSimilarPasswords ? (self.config.checkHibp ? sim : 1.0) : 0;
    
    CGFloat calculatedProgress = (self.hibpProgress * hibpWeight) + (self.similarProgress * similarWeight);
    
    self.progress(calculatedProgress);
}

@end
