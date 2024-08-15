//
//  AbstractPasswordDatabase.h
//  Strongbox
//
//  Created by Mark on 07/11/2017.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "CompositeKeyFactors.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^OpenCompletionBlock)(BOOL userCancelled, DatabaseModel*_Nullable database, NSError*_Nullable innerStreamError, NSError*_Nullable error);
typedef void (^SaveCompletionBlock)(BOOL userCancelled, NSString*_Nullable debugXml, NSError*_Nullable error);

@protocol AbstractDatabaseFormatAdaptor <NSObject>

+ (BOOL)isValidDatabase:(nullable NSData *)prefix error:(NSError**)error;

+ (void)read:(NSInputStream*)stream
         ckf:(CompositeKeyFactors*)ckf
  completion:(OpenCompletionBlock)completion;

+ (void)read:(NSInputStream*)stream
         ckf:(CompositeKeyFactors*)ckf
xmlDumpStream:(NSOutputStream*_Nullable)xmlDumpStream
sanityCheckInnerStream:(BOOL)sanityCheckInnerStream
  completion:(OpenCompletionBlock)completion;

+ (void)save:(DatabaseModel*)database 
outputStream:(NSOutputStream*)outputStream
      params:(id _Nullable)params
  completion:(SaveCompletionBlock)completion;

@property (nonatomic, class, readonly) DatabaseFormat format;
@property (nonatomic, class, readonly) NSString* fileExtension;

@end

NS_ASSUME_NONNULL_END
