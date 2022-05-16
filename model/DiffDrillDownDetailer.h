//
//  DiffDrillDownDetailer.h
//  MacBox
//
//  Created by Strongbox on 06/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MutableOrderedDictionary.h"
#import "DatabaseModel.h"
#import "MMcGPair.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiffDrillDownDetailer : NSObject

+ (MutableOrderedDictionary<NSString*, NSString*> *)initializePairWiseDiffs:(DatabaseModel*)firstDatabase
                 secondDatabase:(DatabaseModel*)secondDatabase
                       diffPair:(MMcGPair<Node*, Node*>*)diffPair
                    isMergeDiff:(BOOL)isMergeDiff;

+ (MutableOrderedDictionary<NSString*, NSString*> *)initializePropertiesDiff:(DatabaseModel*)firstDatabase
                  secondDatabase:(DatabaseModel*)secondDatabase
                     isMergeDiff:(BOOL)isMergeDiff;

@end

NS_ASSUME_NONNULL_END
