//
//  Kdb1Database.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractPasswordDatabase.h"
#import "Kdb1DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdb1Database : NSObject<AbstractPasswordDatabase>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;
+ (NSString *)fileExtension;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) Kdb1DatabaseMetadata* metadata;
@property (nonatomic, retain, nullable) NSString *masterPassword;
@property (nonatomic, readonly, nonnull) NSMutableArray<DatabaseAttachment*>* attachments;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID*, NSData*>* customIcons;

@end

NS_ASSUME_NONNULL_END
