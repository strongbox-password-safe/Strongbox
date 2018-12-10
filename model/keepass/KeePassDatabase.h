#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePassDatabaseMetadata.h"
#import "KeePassConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabase : NSObject<AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate;
+ (NSString *)fileExtension;

- (StrongboxDatabase*)create:(nullable NSString *)password;
- (nullable StrongboxDatabase*)open:(NSData*)data password:(NSString *)password error:(NSError **)error;
- (nullable StrongboxDatabase*)open:(NSData*)data password:(nullable NSString *)password keyFileDigest:(nullable NSData *)keyFileDigest error:(NSError **)error;
- (nullable NSData*)save:(StrongboxDatabase*)database error:(NSError**)error;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

#endif // ifndef _KeypassDatabase_h

NS_ASSUME_NONNULL_END
