
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "PwSafeMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface PwSafeDatabase : NSObject <AbstractDatabaseFormatAdaptor>

@end

#endif // ifndef _PwSafeDatabase_h

NS_ASSUME_NONNULL_END
