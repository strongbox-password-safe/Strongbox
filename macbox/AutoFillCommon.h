//
//  AutoFillCommon.h
//  MacBox
//
//  Created by Strongbox on 29/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Model.h"

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillCommon : NSObject

+ (NSSet<NSString*>*)getUniqueUrlsForNode:(Model*)model
                                     node:(Node*)node;

@end

NS_ASSUME_NONNULL_END
