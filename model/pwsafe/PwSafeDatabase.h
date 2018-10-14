
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractPasswordDatabase.h"

@interface PwSafeDatabase : NSObject <AbstractPasswordDatabase>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

- (void)defaultLastUpdateFieldsToNow;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) NSArray<Node*> *allNodes;
@property (nonatomic) NSInteger keyStretchIterations;
@property (nonatomic, retain, nullable) NSString *masterPassword;
@property (nonatomic, nullable) NSDate *lastUpdateTime;
@property (nonatomic, nullable) NSString *lastUpdateUser;
@property (nonatomic, nullable) NSString *lastUpdateHost;
@property (nonatomic, nullable) NSString *lastUpdateApp;

// Helpers

@property (nonatomic, readonly) NSString * _Nonnull version;

@end

#endif // ifndef _PwSafeDatabase_h
