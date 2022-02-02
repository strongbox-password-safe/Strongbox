//
//  SyncManagement.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef SyncManagement_h
#define SyncManagement_h

#import "CommonDatabasePreferences.h"
#import "SyncAndMergeSequenceManager.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SyncManagement <NSObject>

- (BOOL)updateLocalCopyMarkAsRequiringSync:(METADATA_PTR)database data:(NSData *)data error:(NSError**)error;
- (BOOL)updateLocalCopyMarkAsRequiringSync:(METADATA_PTR)database file:(NSString *)file error:(NSError**)error;
- (void)sync:(METADATA_PTR)database interactiveVC:(VIEW_CONTROLLER_PTR _Nullable)interactiveVC key:(CompositeKeyFactors*)key join:(BOOL)join completion:(SyncAndMergeCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END

#endif /* SyncManagement_h */
