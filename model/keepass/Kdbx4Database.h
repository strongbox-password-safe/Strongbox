//
//  Kdbx4Database.h
//  Strongbox
//
//  Created by Mark on 25/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractDatabaseFormatAdaptor.h"
#import "KeePass4DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface Kdbx4Database : NSObject<AbstractDatabaseFormatAdaptor>

- (void)read:(NSInputStream *)stream
         ckf:(CompositeKeyFactors *)ckf
xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
  completion:(OpenCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
