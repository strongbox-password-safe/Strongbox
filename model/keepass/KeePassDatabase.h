#ifndef _KeypassDatabase_h
#define _KeypassDatabase_h

#import <Foundation/Foundation.h>
#import "Node.h"
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePassDatabaseMetadata.h"
#import "KeePassConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassDatabase : NSObject<AbstractDatabaseFormatAdaptor>

- (void)read:(NSInputStream *)stream
         ckf:(CompositeKeyFactors *)ckf
xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
  completion:(OpenCompletionBlock)completion;

@end

#endif // ifndef _KeypassDatabase_h

NS_ASSUME_NONNULL_END
