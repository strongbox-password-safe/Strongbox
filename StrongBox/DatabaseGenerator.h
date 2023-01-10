//
//  DatabaseGenerator.h
//  Strongbox-iOS
//
//  Created by Mark on 17/04/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseGenerator : NSObject

+ (DatabaseModel*)generateEmpty:(NSString*)password;
+ (DatabaseModel*)generate:(NSString*)password;
+ (DatabaseModel*)generateWithSingleEntry:(NSString*)password;

+ (Node*)generateSampleNode:(Node*)parentGroup;

@end

NS_ASSUME_NONNULL_END
