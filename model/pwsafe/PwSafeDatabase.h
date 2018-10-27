
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractPasswordDatabase.h"
#import "PwSafeMetadata.h"

@interface PwSafeDatabase : NSObject <AbstractPasswordDatabase>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) PwSafeMetadata* metadata;
@property (nonatomic, retain, nullable) NSString *masterPassword;

@end

#endif // ifndef _PwSafeDatabase_h
