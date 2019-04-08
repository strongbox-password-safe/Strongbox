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
    
    Node* sampleFolder = [[Node alloc] initAsGroup:@"Sample Folder" parent:parent uuid:nil];
    [parent addChild:sampleFolder];
    
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
                                                    uuid:nil]];
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

- (NSSet<NSString*> *)usernameSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
for (Node *recordNode in self.allRecords) {
        if ([Utils trim:recordNode.fields.username].length > 0) {
            [bag addObject:recordNode.fields.username];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)emailSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.allRecords) {
        if ([Utils trim:record.fields.email].length > 0) {
            [bag addObject:record.fields.email];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)passwordSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in self.allRecords) {
        if ([Utils trim:record.fields.password].length > 0) {
            [bag addObject:record.fields.password];
        }
    }
    
    return bag;
}

- (NSString *)mostPopularEmail {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.allRecords) {
        if(record.fields.email.length) {
            [bag addObject:record.fields.email];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularUsername {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.allRecords) {
        if(record.fields.username.length) {
            [bag addObject:record.fields.username];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularPassword {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in self.allRecords) {
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

@end
