//
//  SprCompilation.h
//  Strongbox
//
//  Created by Mark on 05/04/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface SprCompilation : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isSprCompilable:(NSString*)test;
- (NSString*)sprCompile:(NSString*)test node:(Node*)node database:(DatabaseModel*)database error:(NSError*_Nullable*)error;

- (NSArray*)matches:(NSString*)test;

@end

NS_ASSUME_NONNULL_END
