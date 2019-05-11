#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"
#import "KeePassDatabase.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "Utils.h"
#import "Kdbx4Database.h"
#import "Kdb1Database.h"
#import "Settings.h"
#import "PasswordGenerator.h"
#import "SprCompilation.h"
#import "NSArray+Extensions.h"
#import "NSMutableArray+Extensions.h"
#import "Kdbx4Serialization.h"
#import "KeePassCiphers.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

NSInteger const kSearchScopeTitle = 0;
NSInteger const kSearchScopeUsername = 1;
NSInteger const kSearchScopePassword = 2;
NSInteger const kSearchScopeUrl = 3;
NSInteger const kSearchScopeAll = 4;

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DatabaseModel ()

@property (nonatomic, strong) StrongboxDatabase* theSafe;
@property (nonatomic, strong) id<AbstractDatabaseFormatAdaptor> adaptor;

@end

@implementation DatabaseModel

+ (BOOL)    isAValidSafe:(nullable NSData *)candidate error:(NSError**)error {
    if(candidate == nil) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is Nil" errorCode:-1];
        }
        return NO;
    }
    if(candidate.length == 0) {
        if(error) {
            *error = [Utils createNSError:@"Database Data is zero length" errorCode:-1];
        }
        return NO;
    }

    NSError *pw, *k1, *k2, *k3;
    
    BOOL ret = [PwSafeDatabase isAValidSafe:candidate error:&pw] ||
          [KeePassDatabase isAValidSafe:candidate error:&k1] ||
          [Kdbx4Database isAValidSafe:candidate error:&k2] ||
          [Kdb1Database isAValidSafe:candidate error:&k3];

    if(error) {
        NSString* errorSummary = @"Could not recognise this a valid Database:\n";
        
        errorSummary = [errorSummary stringByAppendingFormat:@"- Password Safe: %@\n", pw.localizedDescription];
        errorSummary = [errorSummary stringByAppendingFormat:@"- KeePass Classic: %@\n", k1.localizedDescription];
        errorSummary = [errorSummary stringByAppendingFormat:@"- KeePass Advanced: %@\n", k2.localizedDescription];
        errorSummary = [errorSummary stringByAppendingFormat:@"- KeePass 1: %@\n", k3.localizedDescription];
        
        *error = [Utils createNSError:errorSummary errorCode:-1];
    }
    
    return ret;
}

+ (BOOL)isAutoFillLikelyToCrash:(NSData*)data {
    if([Kdbx4Database isAValidSafe:data error:nil]) {
        CryptoParameters* params = [Kdbx4Serialization getCryptoParams:data];
        
        if(params && params.kdfParameters && [params.kdfParameters.uuid isEqual:argon2CipherUuid()]) {
            static NSString* const kParameterMemory = @"M";
            static uint64_t const kMaxArgon2Memory =  64 * 1024 * 1024;
                        
            VariantObject* vo = params.kdfParameters.parameters[kParameterMemory];
            if(vo && vo.theObject) {
                uint64_t memory = ((NSNumber*)vo.theObject).longLongValue;
                if(memory > kMaxArgon2Memory) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

+ (NSString*)getLikelyFileExtension:(NSData *)candidate {
    NSError* error;
    if([PwSafeDatabase isAValidSafe:candidate error:&error]) {
        return [PwSafeDatabase fileExtension];
    }
    else if ([KeePassDatabase isAValidSafe:candidate error:&error]) {
        return [KeePassDatabase fileExtension];
    }
    else if([Kdbx4Database isAValidSafe:candidate error:&error]) {
        return [Kdbx4Database fileExtension];
    }
    else if([Kdb1Database isAValidSafe:candidate error:&error]) {
        return [Kdb1Database fileExtension];
    }
    
    return @"dat";
}

+ (id<AbstractDatabaseFormatAdaptor>)getAdaptor:(DatabaseFormat)format {
    if(format == kPasswordSafe) {
        return [[PwSafeDatabase alloc] init];
    }
    else if(format == kKeePass) {
        return [[KeePassDatabase alloc] init];
    }
    else if(format == kKeePass4) {
        return [[Kdbx4Database alloc] init];
    }
    else if(format == kKeePass1) {
        return [[Kdb1Database alloc] init];
    }
    
    NSLog(@"WARN: No such adaptor for format!");
    return nil;
}

- (instancetype)initNewWithPassword:(NSString *)password keyFileDigest:(NSData*)keyFileDigest format:(DatabaseFormat)format {
    if(self = [super init]) {
        self.adaptor = [DatabaseModel getAdaptor:format];
        self.theSafe = [self.adaptor create:password keyFileDigest:keyFileDigest];
        
        if (self.theSafe == nil) {
            return nil;
        }
        
        if(format != kKeePass1) {
            [self addSampleGroupAndRecordToRoot];
        }
        else {
            Node *parent = self.theSafe.rootGroup.childGroups[0];
            addSampleGroupAndRecordToGroup(parent);
        }
    }
    
    return self;
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    return [self initExistingWithDataAndPassword:safeData password:password keyFileDigest:nil error:ppError];
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                  keyFileDigest:(NSData*)keyFileDigest
                                          error:(NSError **)ppError {

    if(self = [super init]) {
        if([PwSafeDatabase isAValidSafe:safeData error:ppError]) {
            self.adaptor = [[PwSafeDatabase alloc] init];
        }
        else if([KeePassDatabase isAValidSafe:safeData error:ppError]) {
            self.adaptor = [[KeePassDatabase alloc] init];
        }
        else if([Kdbx4Database isAValidSafe:safeData error:ppError]) {
            self.adaptor = [[Kdbx4Database alloc] init];
        }
        else if([Kdb1Database isAValidSafe:safeData error:ppError]) {
            self.adaptor = [[Kdb1Database alloc] init];
        }
        else {
            return nil;
        }

        self.theSafe = [self.adaptor open:safeData password:password keyFileDigest:keyFileDigest error:ppError];
        
        if (self.theSafe == nil) {
            return nil;
        }
    }
    
    return self;
}

- (NSData*)getAsData:(NSError**)error {
    [self.theSafe performPreSerializationTidy]; // Tidy up attachments, custom icons, trim history
    
    return [self.adaptor save:self.theSafe error:error];
}

- (void)addSampleGroupAndRecordToRoot {
    addSampleGroupAndRecordToGroup(self.rootGroup);
}

void addSampleGroupAndRecordToGroup(Node* parent) {
    PasswordGenerationParameters *params = [[Settings sharedInstance] passwordGenerationParameters];
    NSString* password = [PasswordGenerator generatePassword:params];
    
    Node* sampleFolder = [[Node alloc] initAsGroup:@"Sample Folder" parent:parent allowDuplicateGroupTitles:YES uuid:nil];
    [parent addChild:sampleFolder allowDuplicateGroupTitles:NO];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username"
                                                          url:@"https://strongboxsafe.com"
                                                     password:password
                                                        notes:@""
                                                        email:@"user@gmail.com"];

    NSDate* date = [NSDate date];
    fields.created = date;
    fields.accessed = date;
    fields.modified = date;

    [sampleFolder addChild:[[Node alloc] initAsRecord:@"Sample"
                                                 parent:sampleFolder
                                                 fields:fields
                                                    uuid:nil]
      allowDuplicateGroupTitles:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isDereferenceableText:(NSString*)text {
    return self.format != kPasswordSafe && [SprCompilation.sharedInstance isSprCompilable:text];
}

- (NSString*)maybeDeref:(NSString*)text node:(Node*)node maybe:(BOOL)maybe {
    return maybe ? [self dereference:text node:node] : text;
}

- (NSString*)dereference:(NSString*)text node:(Node*)node {
    if(self.format == kPasswordSafe || !text.length) {
        return text;
    }
    
    NSError* error;
    
    BOOL isCompilable = [SprCompilation.sharedInstance isSprCompilable:text];
    
    NSString* compiled = isCompilable ? [SprCompilation.sharedInstance sprCompile:text node:node rootNode:self.rootGroup error:&error] : text;
    
    if(error) {
        NSLog(@"WARN: SPR Compilation ERROR: [%@]", error);
    }
    
    return compiled ? compiled : @""; // Never return nil... just not expected at UI layer
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)getGroupPathDisplayString:(Node *)vm {
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current != nil && current != self.rootGroup) {
        [hierarchy insertObject:current.title atIndex:0];
        current = current.parent;
    }
    
    return hierarchy.count ? [hierarchy componentsJoinedByString:@"/"] : @"/";
}

- (NSString *)getSearchParentGroupPathDisplayString:(Node *)vm {
    if(!vm || vm.parent == nil || vm.parent == self.rootGroup) {
        return @"/";
    }
    
    NSMutableArray<NSString*> *hierarchy = [NSMutableArray array];
    
    Node* current = vm;
    while (current.parent != nil && current.parent != self.rootGroup) {
        [hierarchy insertObject:current.parent.title atIndex:0]; 
        current = current.parent;
    }
    
    NSString *path = [hierarchy componentsJoinedByString:@"/"];
    
    return path;
}

- (Node*)rootGroup {
    if(self.format == kKeePass || self.format == kKeePass4) {
        // Hide the root group - Can not add entries and not really useful - Perhaps make this optional?
        // Later discovery: KeePass 1 allows multiple root groups but no entries to root, Had to put in
        // Code to block root entry additions, meaning that we could display the root group here if we
        // wanted to, and block entries. For the moment, happy to hide the root group for KeePass 3 and 4
        // we'll see if there is some feedback on this. Root Group seems to be pretty useless
        
        if(self.theSafe.rootGroup.children.count > 0) {
            return [self.theSafe.rootGroup.children objectAtIndex:0];
        }
        else {
            return self.theSafe.rootGroup; // This should never be able to happen but for safety
        }
    }
    else {
        return self.theSafe.rootGroup;
    }
}

- (DatabaseFormat)format {
    return self.adaptor.format;
}

- (NSString *)fileExtension {
    return self.adaptor.fileExtension;
}

-(id<AbstractDatabaseMetadata>)metadata {
    return self.theSafe.metadata;
}

-(NSArray *)attachments {
    return self.theSafe.attachments;
}

- (NSDictionary<NSUUID *,NSData *> *)customIcons {
    return self.theSafe.customIcons;
}

-(NSString*)masterPassword {
    return self.theSafe.masterPassword;
}

-(void)setMasterPassword:(NSString *)masterPassword {
    self.theSafe.masterPassword = masterPassword;
}

- (NSData *)keyFileDigest {
    return self.theSafe.keyFileDigest;
}

- (void)setKeyFileDigest:(NSData *)keyFileDigest {
    self.theSafe.keyFileDigest = keyFileDigest;
}

- (void)addNodeAttachment:(Node *)node attachment:(UiAttachment*)attachment {
    [self.theSafe addNodeAttachment:node attachment:attachment];
}

- (void)removeNodeAttachment:(Node *)node atIndex:(NSUInteger)atIndex {
    [self.theSafe removeNodeAttachment:node atIndex:atIndex];
}

- (void)setNodeAttachments:(Node *)node attachments:(NSArray<UiAttachment *> *)attachments {
    [self.theSafe setNodeAttachments:node attachments:attachments];
}

- (void)setNodeCustomIcon:(Node *)node data:(NSData *)data {
    [self.theSafe setNodeCustomIcon:node data:data];
}

- (BOOL)recycleBinEnabled {
    return self.theSafe.recycleBinEnabled;
}

- (Node*)recycleBinNode {
    return self.theSafe.recycleBinNode;
}

- (void)createNewRecycleBinNode {
    [self.theSafe createNewRecycleBinNode];
}

- (Node *)keePass1BackupNode {
    return self.theSafe.keePass1BackupNode;
}
////////////////////////////////////////////////////////////////////////////////////////////
// Convenience

- (NSArray<Node *>*)allNodes {
    return [self.rootGroup filterChildren:YES predicate:nil];
}

-(NSArray<Node *> *)allRecords {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
}

-(NSArray<Node *> *)allGroups {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }];
}

- (NSArray<Node *> *)activeGroups {
    if(self.format == kPasswordSafe) {
        return self.allGroups;
    }
    else if(self.format == kKeePass1) {
        // Filter Backup Group
        // TODO: Expired
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return node.isGroup && (self.keePass1BackupNode == nil || (node != self.keePass1BackupNode && ![self.keePass1BackupNode contains:node]));
        }];
    }
    else {
        // Filter Recycle Bin
        // TODO: Expired
        Node* recycleBin = self.recycleBinNode;
        
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return node.isGroup && (recycleBin == nil || (node != recycleBin && ![recycleBin contains:node]));
        }];
    }
}

- (NSArray<Node *> *)activeRecords {
    if(self.format == kPasswordSafe) {
        return self.allRecords;
    }
    else if(self.format == kKeePass1) {
        // Filter Backup Group
        // TODO: Expired
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && (self.keePass1BackupNode == nil || ![self.keePass1BackupNode contains:node]);
        }];
    }
    else {
        // Filter Recycle Bin
        // TODO: Expired
        Node* recycleBin = self.recycleBinNode;
        
        return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
            return !node.isGroup && (recycleBin == nil || ![recycleBin contains:node]);
        }];
    }
}

- (NSSet<NSString*> *)urlSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *recordNode in self.activeRecords) {
        if ([Utils trim:recordNode.fields.url].length > 0) {
            [bag addObject:recordNode.fields.url];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)usernameSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *recordNode in self.activeRecords) {
        if ([Utils trim:recordNode.fields.username].length > 0) {
            [bag addObject:recordNode.fields.username];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)emailSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if ([Utils trim:record.fields.email].length > 0) {
            [bag addObject:record.fields.email];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)passwordSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if ([Utils trim:record.fields.password].length > 0) {
            [bag addObject:record.fields.password];
        }
    }
    
    return bag;
}

- (NSString *)mostPopularEmail {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if(record.fields.email.length) {
            [bag addObject:record.fields.email];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularUsername {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        if(record.fields.username.length) {
            [bag addObject:record.fields.username];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularPassword {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.activeRecords) {
        [bag addObject:record.fields.password];
    }
    
    return [self mostFrequentInCountedSet:bag];
}

-(NSInteger)numberOfRecords {
    return self.allRecords.count;
}

-(NSInteger)numberOfGroups {
    return self.allGroups.count;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString*)mostFrequentInCountedSet:(NSCountedSet<NSString*>*)bag {
    NSString *mostOccurring = nil;
    NSUInteger highest = 0;
    
    for (NSString *s in bag) {
        if ([bag countForObject:s] > highest) {
            highest = [bag countForObject:s];
            mostOccurring = s;
        }
    }
    
    return mostOccurring;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Search...

- (NSArray<Node*>*)search:(NSString *)searchText
                    scope:(NSInteger)scope
              dereference:(BOOL)dereference
    includeKeePass1Backup:(BOOL)includeKeePass1Backup
        includeRecycleBin:(BOOL)includeRecycleBin {
    NSArray<NSString*>* terms = [self getSearchTerms:searchText];
    
    //NSLog(@"Search for nodes containing: [%@]", terms);

    NSMutableArray* results = [self.allNodes mutableCopy]; // Mutable for memory/perf reasons
    
    for (NSString* word in terms) {
        [self filterForWord:results
                 searchText:word
                      scope:scope
                dereference:dereference
      includeKeePass1Backup:includeKeePass1Backup
          includeRecycleBin:includeRecycleBin];
    }
    
    [self filterExcludedSearchItems:results includeKeePass1Backup:includeKeePass1Backup includeRecycleBin:includeRecycleBin];
    
    [results sortUsingComparator:finderStyleNodeComparator];
    
    return results;
}

- (NSArray<NSString*>*)getSearchTerms:(NSString *)searchText {
    NSArray* split = [searchText componentsSeparatedByString:@" "];
    NSMutableSet<NSString*>* unique = [NSMutableSet setWithArray:split];
    [unique removeObject:@""];
    
    // Split into words and sort by longest word first to eliminate most entries...
    
    return [unique.allObjects sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [@(((NSString*)obj2).length) compare:@(((NSString*)obj1).length)];
    }];
}

- (void)filterForWord:(NSMutableArray<Node*>*)searchNodes
           searchText:(NSString *)searchText
                scope:(NSInteger)scope
          dereference:(BOOL)dereference
includeKeePass1Backup:(BOOL)includeKeePass1Backup
    includeRecycleBin:(BOOL)includeRecycleBin {
    if (scope == kSearchScopeTitle) {
        [self searchTitle:searchNodes searchText:searchText dereference:dereference];
    }
    else if (scope == kSearchScopeUsername) {
        [self searchUsername:searchNodes searchText:searchText dereference:dereference];
    }
    else if (scope == kSearchScopePassword) {
        [self searchPassword:searchNodes searchText:searchText dereference:dereference];
    }
    else if (scope == kSearchScopeUrl) {
        [self searchUrl:searchNodes searchText:searchText dereference:dereference];
    }
    else {
        [self searchAllFields:searchNodes searchText:searchText dereference:dereference];
    }
}

- (void)searchTitle:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self isTitleMatches:searchText node:node dereference:dereference];
    }];
}

- (void)searchUsername:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self isUsernameMatches:searchText node:node dereference:dereference];
    }];
}

- (void)searchPassword:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self isPasswordMatches:searchText node:node dereference:dereference];
    }];
}

- (void)searchUrl:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self isUrlMatches:searchText node:node dereference:dereference];
    }];
}

- (void)searchAllFields:(NSMutableArray<Node*>*)searchNodes searchText:(NSString*)searchText dereference:(BOOL)dereference {
    [searchNodes mutableFilter:^BOOL(Node * _Nonnull node) {
        return [self isAllFieldsMatches:searchText node:node dereference:dereference];
    }];
}

- (BOOL)isTitleMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.title node:node maybe:dereference];
    return [foo localizedCaseInsensitiveContainsString:searchText];
}

- (BOOL)isUsernameMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.username node:node maybe:dereference];
    return [foo localizedCaseInsensitiveContainsString:searchText];
}

- (BOOL)isPasswordMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.password node:node maybe:dereference];
    return [foo localizedCaseInsensitiveContainsString:searchText];
}

- (BOOL)isUrlMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* foo = [self maybeDeref:node.fields.url node:node maybe:dereference];
    return [foo localizedCaseInsensitiveContainsString:searchText];
}

- (BOOL)isAllFieldsMatches:(NSString*)searchText node:(Node*)node dereference:(BOOL)dereference {
    NSString* title = [self maybeDeref:node.title node:node maybe:dereference];
    NSString* username = [self maybeDeref:node.fields.username node:node maybe:dereference];
    NSString* password = [self maybeDeref:node.fields.password node:node maybe:dereference];
    NSString* url = [self maybeDeref:node.fields.url node:node maybe:dereference];
    NSString* email = [self maybeDeref:node.fields.email node:node maybe:dereference];
    NSString* notes = [self maybeDeref:node.fields.notes node:node maybe:dereference];
    
    BOOL simple =   [title localizedCaseInsensitiveContainsString:searchText] ||
    [username localizedCaseInsensitiveContainsString:searchText] ||
    [password localizedCaseInsensitiveContainsString:searchText] ||
    [email localizedCaseInsensitiveContainsString:searchText] ||
    [url localizedCaseInsensitiveContainsString:searchText] ||
    [notes localizedCaseInsensitiveContainsString:searchText];
    
    if(simple) {
        return YES;
    }
    else {
        if (self.format == kKeePass4 || self.format == kKeePass) {
            for (NSString* key in node.fields.customFields.allKeys) {
                NSString* value = node.fields.customFields[key].value;
                
                if ([key localizedCaseInsensitiveContainsString:searchText] || [value localizedCaseInsensitiveContainsString:searchText]) {
                    return YES;
                }
            }
        }
        
        if (self.format != kPasswordSafe) {
            BOOL attachmentMatch = [node.fields.attachments anyMatch:^BOOL(NodeFileAttachment* _Nonnull obj) {
                return [obj.filename localizedCaseInsensitiveContainsString:searchText];
            }];
            
            if (attachmentMatch) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)filterExcludedSearchItems:(NSMutableArray<Node*>*)matches
            includeKeePass1Backup:(BOOL)includeKeePass1Backup
                includeRecycleBin:(BOOL)includeRecycleBin {
    if(!includeKeePass1Backup) {
        if (self.format == kKeePass1) {
            Node* backupGroup = self.keePass1BackupNode;
            if(backupGroup) {
                [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
                    return (obj != backupGroup && ![backupGroup contains:obj]);
                }];
            }
        }
    }
    
    Node* recycleBin = self.recycleBinNode;
    if(!includeRecycleBin && recycleBin) {
        [matches mutableFilter:^BOOL(Node * _Nonnull obj) {
            return obj != recycleBin && ![recycleBin contains:obj];
        }];
    }
}

@end
