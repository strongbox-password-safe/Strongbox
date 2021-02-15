//
//  SampleItemsGenerator.h
//  Strongbox
//
//  Created by Strongbox on 20/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"
#import "PasswordGenerationConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface SampleItemsGenerator : NSObject

+ (void)addSampleGroupAndRecordToRoot:(DatabaseModel*)database
                       passwordConfig:(PasswordGenerationConfig*)passwordConfig;

@end

NS_ASSUME_NONNULL_END
