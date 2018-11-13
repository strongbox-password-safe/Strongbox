#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"
#import "KeePassDatabase.h"
#import "AbstractPasswordDatabase.h"
#import "Utils.h"
#import "Kdbx4Database.h"
#import "Kdb1Database.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DatabaseModel ()

@property (nonatomic, strong) id<AbstractPasswordDatabase> theSafe;

@end

@implementation DatabaseModel

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return  [PwSafeDatabase isAValidSafe:candidate] ||
            [KeePassDatabase isAValidSafe:candidate] ||
            [Kdbx4Database isAValidSafe:candidate] ||
            [Kdb1Database isAValidSafe:candidate];
}

+ (NSString*)getLikelyFileExtension:(NSData *)candidate {
    if([PwSafeDatabase isAValidSafe:candidate]) {
        return [PwSafeDatabase fileExtension];
    }
    else if ([KeePassDatabase isAValidSafe:candidate]) {
        return [KeePassDatabase fileExtension];
    }
    else if([Kdbx4Database isAValidSafe:candidate]) {
        return [Kdbx4Database fileExtension];
    }
    else if([Kdb1Database isAValidSafe:candidate]) {
        return [Kdb1Database fileExtension];
    }
    
    return @"dat";
}

- (instancetype)initNewWithoutPassword:(DatabaseFormat)format {
    return [self initNewWithPassword:nil format:format];
}

- (instancetype)initNewWithPassword:(NSString *)password format:(DatabaseFormat)format {
    if(self = [super init]) {
        if(format == kPasswordSafe) {
            self.theSafe = [[PwSafeDatabase alloc] initNewWithPassword:password];
            [self addSampleGroupAndRecordToRoot];
        }
        else if(format == kKeePass) {
            self.theSafe = [[KeePassDatabase alloc] initNewWithPassword:password];
            [self addSampleGroupAndRecordToRoot];
        }
        else if(format == kKeePass4) {
            self.theSafe = [[Kdbx4Database alloc] initNewWithPassword:password];
            [self addSampleGroupAndRecordToRoot];
        }
        else if(format == kKeePass1) {
            self.theSafe = [[Kdb1Database alloc] initNewWithPassword:password];
            if (self.theSafe == nil) {
                return nil;
            }
            
            Node *parent = self.theSafe.rootGroup.childGroups[0];
            addSampleGroupAndRecordToGroup(parent);
        }
        else {
            return nil;
        }
        
        if (self.theSafe == nil) {
            return nil;
        }
    }
    
    return self;
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    if(self = [super init]) {
        if([PwSafeDatabase isAValidSafe:safeData]) {
            self.theSafe = [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
        }
        else if([KeePassDatabase isAValidSafe:safeData]) {
            self.theSafe = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
        }
        else if([Kdbx4Database isAValidSafe:safeData]) {
            self.theSafe = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
        }
        else if([Kdb1Database isAValidSafe:safeData]) {
            self.theSafe = [[Kdb1Database alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
        }
        else {
            return nil;
        }
        
        if (self.theSafe == nil) {
            return nil;
        }
    }
    
    return self;
}

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error {
    return [self.theSafe getAsData:error];
}

- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords {
    return [self.theSafe getDiagnosticDumpString:plaintextPasswords];
}

- (void)addSampleGroupAndRecordToRoot {
    addSampleGroupAndRecordToGroup(self.rootGroup);
}

void addSampleGroupAndRecordToGroup(Node* parent) {
    [parent addChild:[[Node alloc] initAsGroup:@"Sample Group" parent:parent uuid:nil]];
    
    NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username"
                                                          url:@"https://www.google.com"
                                                     password:@"password"
                                                        notes:@""
                                                        email:@"user@gmail.com"];
    
    [parent addChild:[[Node alloc] initAsRecord:@"Sample Entry"
                                                 parent:parent
                                                 fields:fields
                                                    uuid:nil]];
}

- (Node*)rootGroup {
    if(self.theSafe.format == kKeePass || self.theSafe.format == kKeePass4) {
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
    return self.theSafe.format;
}

- (NSString *)fileExtension {
    return self.theSafe.fileExtension;
}

-(id<AbstractDatabaseMetadata>)metadata {
    return self.theSafe.metadata;
}

-(NSMutableArray *)attachments {
    return self.theSafe.attachments;
}

- (NSMutableDictionary<NSUUID *,NSData *> *)customIcons {
    return self.theSafe.customIcons;
}

-(NSString*)masterPassword {
    return self.theSafe.masterPassword;
}

-(void)setMasterPassword:(NSString *)masterPassword {
    self.theSafe.masterPassword = masterPassword;
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
