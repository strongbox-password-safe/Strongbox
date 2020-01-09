//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseMetadata.h"

@interface DatabasesManager : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<DatabaseMetadata*> *snapshot;

- (void)add:(DatabaseMetadata *_Nonnull)safe;

- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)update:(DatabaseMetadata *_Nonnull)safe;

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;
- (NSArray<DatabaseMetadata*>* _Nonnull)getSafesOfProvider:(StorageProvider)storageProvider;

@end
