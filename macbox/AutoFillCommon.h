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

+ (NSSet<NSString*>*)getUniqueUrlsForNode:(DatabaseModel*)database
                                     node:(Node*)node
                          alternativeUrls:(BOOL)alternativeUrls
                             customFields:(BOOL)customFields
                                    notes:(BOOL)notes;
@end

NS_ASSUME_NONNULL_END
