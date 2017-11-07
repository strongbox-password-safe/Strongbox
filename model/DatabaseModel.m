#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PwSafeDatabase.h"

//////////////////////////////////////////////////////////////////////////////////////////////////////

@interface DatabaseModel ()

@property (nonatomic, strong) PwSafeDatabase* theSafe;

@end

@implementation DatabaseModel

+ (BOOL)isAValidSafe:(NSData *)candidate {
    return [PwSafeDatabase isAValidSafe:candidate];
}

- (instancetype)initNewWithoutPassword {
    return [[PwSafeDatabase alloc] initNewWithPassword:nil];
}

- (instancetype)initNewWithPassword:(NSString *)password {
    return [[PwSafeDatabase alloc] initNewWithPassword:password];
}

- (instancetype)initExistingWithDataAndPassword:(NSData *)safeData
                                       password:(NSString *)password
                                          error:(NSError **)ppError {
    return [[PwSafeDatabase alloc] initExistingWithDataAndPassword:safeData password:password error:ppError];
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

@end
