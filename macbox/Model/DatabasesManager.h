//
//  SafesList.h
//  Strongbox
//
//  Created by Mark on 30/03/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabasesManager : NSObject

+ (instancetype _Nullable)sharedInstance;

@property (nonatomic, nonnull, readonly) NSArray<DatabaseMetadata*> *snapshot;

- (void)add:(DatabaseMetadata *_Nonnull)safe;
- (void)remove:(NSString*_Nonnull)uuid;
- (void)move:(NSInteger)sourceIndex to:(NSInteger)destinationIndex;
- (void)update:(DatabaseMetadata *_Nonnull)safe;

+ (NSString *_Nonnull)sanitizeSafeNickName:(NSString *_Nonnull)string;
- (BOOL)isValidNickName:(NSString *_Nonnull)nickName;

- (DatabaseMetadata*_Nullable)getDatabaseByFileUrl:(NSURL *)url;
- (DatabaseMetadata*)addOrGet:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
