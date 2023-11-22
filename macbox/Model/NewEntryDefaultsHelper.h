//
//  NewEntryDefaultsHelper.h
//  MacBox
//
//  Created by Strongbox on 12/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface NewEntryDefaultsHelper : NSObject

+ (Node*)getDefaultNewEntryNode:(DatabaseModel*)database parentGroup:(Node *_Nonnull)parentGroup;

@end

NS_ASSUME_NONNULL_END
