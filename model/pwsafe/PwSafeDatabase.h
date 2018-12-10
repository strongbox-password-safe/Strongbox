
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "PwSafeMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface PwSafeDatabase : NSObject <AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate;
+ (NSString *)fileExtension;

- (StrongboxDatabase*)create:(nullable NSString *)password;
- (nullable StrongboxDatabase*)open:(NSData*)data password:(NSString *)password error:(NSError **)error;
- (nullable StrongboxDatabase*)open:(NSData*)data password:(nullable NSString *)password keyFileDigest:(nullable NSData *)keyFileDigest error:(NSError **)error;
- (nullable NSData*)save:(StrongboxDatabase*)database error:(NSError**)error;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

#endif // ifndef _PwSafeDatabase_h

NS_ASSUME_NONNULL_END
