//
//  Kdb1Database.h
//  Strongbox
//
//  Created by Mark on 08/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "Kdb1DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdb1Database : NSObject<AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate;
+ (NSString *)fileExtension;

- (StrongboxDatabase*)create:(nullable NSString *)password;
- (nullable StrongboxDatabase*)open:(NSData*)data password:(NSString *)password error:(NSError **)error;
- (nullable NSData*)save:(StrongboxDatabase*)database error:(NSError**)error;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

NS_ASSUME_NONNULL_END
