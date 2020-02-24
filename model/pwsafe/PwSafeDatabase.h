
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "PwSafeMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface PwSafeDatabase : NSObject <AbstractDatabaseFormatAdaptor>

+ (BOOL)isAValidSafe:(nullable NSData *)candidate error:(NSError**)error;
+ (NSString *)fileExtension;

@property (nonatomic, readonly) DatabaseFormat format;
@property (nonatomic, readonly) NSString* fileExtension;

@end

#endif // ifndef _PwSafeDatabase_h

NS_ASSUME_NONNULL_END
