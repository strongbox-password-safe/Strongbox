//
//  DatabaseDiffer.h
//  Strongbox
//
//  Created by Strongbox on 02/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DiffSummary.h"
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseDiffer : NSObject

+ (DiffSummary *)diff:(DatabaseModel*)beforeDb second:(DatabaseModel*)afterDb;

@end

NS_ASSUME_NONNULL_END
