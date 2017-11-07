#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"

@interface KeypassDatabase : NSObject

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, retain, nullable) NSString *masterPassword;
@property (nonatomic, readonly, nonnull) Node* rootGroup;


// Helpers

//- (void)defaultLastUpdateFieldsToNow;
//@property (nonatomic) NSInteger keyStretchIterations;
//@property (nonatomic, nullable) NSDate *lastUpdateTime;
//@property (nonatomic, nullable) NSString *lastUpdateUser;
//@property (nonatomic, nullable) NSString *lastUpdateHost;
//@property (nonatomic, nullable) NSString *lastUpdateApp;

//@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull usernameSet;
//@property (nonatomic, readonly, copy) NSSet<NSString*>* _Nonnull passwordSet;
//@property (nonatomic, readonly) NSString* _Nonnull mostPopularUsername;
//@property (nonatomic, readonly) NSString* _Nonnull mostPopularPassword;
//
//@property (nonatomic, readonly) NSInteger numberOfRecords;
//@property (nonatomic, readonly) NSInteger numberOfGroups;
//@property (nonatomic, readonly) NSString * _Nonnull version;

@end

#endif // ifndef _KeypassDatabase_h
