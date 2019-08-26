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
#import "StrongboxDatabase.h"
#import "CompositeKeyFactors.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM (NSInteger, DatabaseFormat) {
    kPasswordSafe,
    kKeePass,
    kKeePass4,
    kKeePass1,
    kFormatUnknown,
};

@protocol AbstractDatabaseFormatAdaptor <NSObject>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;
+ (NSString *)fileExtension;
+ (NSData *_Nullable)getYubikeyChallenge:(NSData *)candidate error:(NSError**)error;

- (StrongboxDatabase*)create:(CompositeKeyFactors*)compositeKeyFactors;
- (nullable StrongboxDatabase*)open:(NSData*)data compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors error:(NSError **)error;

- (nullable NSData*)save:(StrongboxDatabase*)database error:(NSError**)error;


@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

NS_ASSUME_NONNULL_END
