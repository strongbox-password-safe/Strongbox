#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"
#import "KeePassDatabase.h"
#import "AbstractPasswordDatabase.h"
#import "Utils.h"
#import "Kdbx4Database.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DatabaseModel ()

@property (nonatomic, strong) id<AbstractPasswordDatabase> theSafe;

@end

@implementation DatabaseModel

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [PwSafeDatabase isAValidSafe:candidate];
//    ||
//            [KeePassDatabase isAValidSafe:candidate] ||
//            [Kdbx4Database isAValidSafe:candidate];
}

- (instancetype)initNewWithoutPassword {
    if(self = [super init]) {
        self.theSafe = [[PwSafeDatabase alloc] initNewWithPassword:nil];
    }
    
    return self;
}

- (instancetype)initNewWithPassword:(NSString *)password {
    if(self = [super init]) {
        self.theSafe = [[PwSafeDatabase alloc] initNewWithPassword:password];
        
        [[self.theSafe rootGroup] addChild:[[Node alloc] initAsGroup:@"New Group" parent:[self.theSafe rootGroup] uuid:nil]];
        
        NodeFields *fields = [[NodeFields alloc] initWithUsername:@"username"
                                         url:@"https://www.google.com"
                                    password:@"password"
                                       notes:@""
                                       email:@"user@gmail.com"];
        
        [[self.theSafe rootGroup] addChild:[[Node alloc] initAsRecord:@"New Entry"
                                                               parent:[self.theSafe rootGroup]
                                                               fields:fields
                                                                 uuid:nil]];
    }
    
    return self;
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    if(self = [super init]) {
        if([PwSafeDatabase isAValidSafe:safeData]) {
            self.theSafe = [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
            if (self.theSafe == nil) {
                return nil;
            }
            
            _format = kPasswordSafe;
        }
//        else if([KeePassDatabase isAValidSafe:safeData]) {
//            self.theSafe = [[KeePassDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
//            _format = kKeePass;
//        }
//        else if([Kdbx4Database isAValidSafe:safeData]) {
//            self.theSafe = [[Kdbx4Database alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
//            _format = kKeePass4;
//        }
        else {
            self = nil;
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

- (Node*)rootGroup {
    return self.theSafe.rootGroup;
}

-(id<AbstractDatabaseMetadata>)metadata {
    return self.theSafe.metadata;
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
