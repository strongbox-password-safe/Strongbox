#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractPasswordDatabase.h"
#import <stdint.h>

typedef struct _KeepassHeader {
    uint8_t signature1[4];
    uint8_t signature2[4];
    uint16_t minor;
    uint16_t major;
} KeepassHeader;

#define SIZE_OF_KEEPASS_HEADER      12

@interface KeypassDatabase : NSObject<AbstractPasswordDatabase>

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

- (void)defaultLastUpdateFieldsToNow;

@property (nonatomic) NSInteger keyStretchIterations;
@property (nonatomic, nullable) NSDate *lastUpdateTime;
@property (nonatomic, nullable) NSString *lastUpdateUser;
@property (nonatomic, nullable) NSString *lastUpdateHost;
@property (nonatomic, nullable) NSString *lastUpdateApp;

@property (nonatomic, readonly) NSString * _Nonnull version;

@end

#endif // ifndef _KeypassDatabase_h
