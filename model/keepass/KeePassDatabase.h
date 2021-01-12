#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePassConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabase : NSObject<AbstractDatabaseFormatAdaptor>

@end

#endif // ifndef _KeypassDatabase_h

NS_ASSUME_NONNULL_END
