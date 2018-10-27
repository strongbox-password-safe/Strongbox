#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractPasswordDatabase.h"
#import <stdint.h>
#import "KeePassDatabaseMetadata.h"
#import "KeePassConstants.h"

@interface KeePassDatabase : NSObject<AbstractPasswordDatabase>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) KeePassDatabaseMetadata* metadata;
@property (nonatomic, retain, nullable) NSString *masterPassword;

@end

#endif // ifndef _KeypassDatabase_h
