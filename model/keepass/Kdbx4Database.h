//
//  Kdbx4Database.h
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractPasswordDatabase.h"
#import "KeePassDatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4Database : NSObject<AbstractPasswordDatabase>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) KeePassDatabaseMetadata* metadata; // TODO: 
@property (nonatomic, retain, nullable) NSString *masterPassword;

@end

NS_ASSUME_NONNULL_END
