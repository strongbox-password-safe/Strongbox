#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"
#import "KeypassDatabase.h"
#import "AbstractPasswordDatabase.h"
#import "Utils.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DatabaseModel ()

@property (nonatomic, strong) id<AbstractPasswordDatabase> theSafe;

@end

@implementation DatabaseModel

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [PwSafeDatabase isAValidSafe:candidate] || [KeypassDatabase isAValidSafe:candidate];
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
    }
    
    return self;
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    if(self = [super init]) {
        if([PwSafeDatabase isAValidSafe:safeData]) {
            self.theSafe = [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
            _format = kPasswordSafe;
        }
        else {
            self.theSafe = [[KeypassDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
            _format = kKeypass;
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

- (void)defaultLastUpdateFieldsToNow {
    return [self.theSafe defaultLastUpdateFieldsToNow];
}

- (Node*)rootGroup {
    return self.theSafe.rootGroup;
}

-(NSString*)masterPassword {
    return self.theSafe.masterPassword;
}

-(void)setMasterPassword:(NSString *)masterPassword {
    self.theSafe.masterPassword = masterPassword;
}

-(NSDate *)lastUpdateTime {
    return self.theSafe.lastUpdateTime;
}

-(void)setLastUpdateTime:(NSDate *)lastUpdateTime {
    self.theSafe.lastUpdateTime = lastUpdateTime;
}

-(NSString *)lastUpdateUser {
    return self.theSafe.lastUpdateUser;
}

-(void)setLastUpdateUser:(NSString *)lastUpdateUser {
    self.theSafe.lastUpdateUser = lastUpdateUser;
}

-(NSString *)lastUpdateHost {
    return self.theSafe.lastUpdateHost;
}

-(void)setLastUpdateHost:(NSString *)lastUpdateHost {
    self.theSafe.lastUpdateHost = lastUpdateHost;
}

-(NSString *)lastUpdateApp {
    return self.theSafe.lastUpdateApp;
}

-(void)setLastUpdateApp:(NSString *)lastUpdateApp {
    self.theSafe.lastUpdateApp = lastUpdateApp;
}

-(NSString *)version {
    return self.theSafe.version;
}

////////////////////////////////////////////////////////////////////////////////////////////
// Convenience

- (NSArray<Node*>*)getAllRecords {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return !node.isGroup;
    }];
}

- (NSArray<Node*>*)getAllGroups {
    return [self.rootGroup filterChildren:YES predicate:^BOOL(Node * _Nonnull node) {
        return node.isGroup;
    }];
}

- (NSSet<NSString*> *)usernameSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *recordNode in [self getAllRecords]) {
        if ([Utils trim:recordNode.fields.username].length > 0) {
            [bag addObject:recordNode.fields.username];
        }
    }
    
    return bag;
}

- (NSSet<NSString*> *)passwordSet {
    NSMutableSet<NSString*> *bag = [[NSMutableSet alloc]init];
    
    for (Node *record in [self getAllRecords]) {
        if ([Utils trim:record.fields.password].length > 0) {
            [bag addObject:record.fields.password];
        }
    }
    
    return bag;
}

- (NSString *)mostPopularUsername {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in [self getAllRecords]) {
        if(record.fields.username.length) {
            [bag addObject:record.fields.username];
        }
    }
    
    return [self mostFrequentInCountedSet:bag];
}

- (NSString *)mostPopularPassword {
    NSCountedSet<NSString*> *bag = [[NSCountedSet alloc]init];
    
    for (Node *record in [self getAllRecords]) {
        [bag addObject:record.fields.password];
    }
    
    return [self mostFrequentInCountedSet:bag];
}

-(NSInteger)numberOfRecords {
    return [self getAllRecords].count;
}

-(NSInteger)numberOfGroups {
    return [self getAllGroups].count;
}


// TODO

-(NSInteger)keyStretchIterations {
    return self.theSafe.keyStretchIterations;
}

- (void)setKeyStretchIterations:(NSInteger)keyStretchIterations {
    self.theSafe.keyStretchIterations = keyStretchIterations;
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
