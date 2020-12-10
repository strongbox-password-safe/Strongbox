
#ifndef _PwSafeDatabase_h
#define _PwSafeDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"

NS_ASSUME_NONNULL_BEGIN

extern const NSInteger kPwSafeDefaultVersionMajor;
extern const NSInteger kPwSafeDefaultVersionMinor;

@interface PwSafeDatabase : NSObject <AbstractDatabaseFormatAdaptor>

@end

#endif 

NS_ASSUME_NONNULL_END
