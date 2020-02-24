#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePassDatabaseMetadata.h"
#import "KeePassConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabase : NSObject<AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;

+ (NSString *)fileExtension;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

#endif // ifndef _KeypassDatabase_h

NS_ASSUME_NONNULL_END
