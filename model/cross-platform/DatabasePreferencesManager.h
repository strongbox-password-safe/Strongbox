//
//  DatabasePreferencesManager.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef DatabasePreferencesManager_h
#define DatabasePreferencesManager_h

#if TARGET_OS_IPHONE

#import "SafeMetaData.h"
typedef SafeMetaData* METADATA_PTR;

#else

#import "DatabaseMetadata.h"
typedef DatabaseMetadata* METADATA_PTR;

#endif

NS_ASSUME_NONNULL_BEGIN

@protocol DatabasePreferencesManager <NSObject>

@property (nonatomic, nonnull, readonly) NSArray<METADATA_PTR> *snapshot;

- (METADATA_PTR _Nullable)getDatabaseById:(NSString*)uuid;

- (void)update:(METADATA_PTR _Nonnull)database;
- (void)atomicUpdate:(NSString *_Nonnull)uuid touch:(void (^_Nonnull)(METADATA_PTR metadata))touch;

@end

NS_ASSUME_NONNULL_END

#endif /* DatabasePreferencesManager_h */
