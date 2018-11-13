//
//  AbstractPasswordDatabase.h
//  Strongbox
//
//  Created by Mark on 07/11/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseMetadata.h"
#import "DatabaseAttachment.h"

typedef enum {
    kPasswordSafe,
    kKeePass,
    kKeePass4,
    kKeePass1,
} DatabaseFormat;

@protocol AbstractPasswordDatabase <NSObject>

+ (BOOL)isAValidSafe:(NSData *_Nonnull)candidate;

- (instancetype _Nullable )init NS_UNAVAILABLE;
- (instancetype _Nullable )initNewWithoutPassword;
- (instancetype _Nullable )initNewWithPassword:(NSString *_Nullable)password;
- (instancetype _Nullable )initExistingWithDataAndPassword:(NSData *_Nonnull)data password:(NSString *_Nonnull)password error:(NSError *_Nonnull*_Nonnull)ppError;

- (NSData* _Nullable)getAsData:(NSError*_Nonnull*_Nonnull)error;
- (NSString*_Nonnull)getDiagnosticDumpString:(BOOL)plaintextPasswords;

@property (nonatomic, readonly, nonnull) Node* rootGroup;
@property (nonatomic, readonly, nonnull) id<AbstractDatabaseMetadata> metadata;
@property (nonatomic, readonly, nonnull) NSMutableArray<DatabaseAttachment*> *attachments;
@property (nonatomic, readonly, nonnull) NSMutableDictionary<NSUUID*, NSData*>* customIcons;

@property (nonatomic, retain, nullable) NSString *masterPassword;
@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly, nonnull) NSString* fileExtension;

@end
