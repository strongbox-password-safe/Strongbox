//
//  DryRunReport.h
//  Strongbox
//
//  Created by Strongbox on 30/12/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "MMcGPair.h"

NS_ASSUME_NONNULL_BEGIN

@interface DiffSummary : NSObject

@property NSArray<NSUUID*>* onlyInFirst;
@property NSArray<NSUUID*>* onlyInSecond;
@property NSArray<NSUUID*>* edited;
@property NSArray<NSUUID*>* historicalChanges;
@property NSArray<NSUUID*>* moved;
@property NSArray<NSUUID*>* reordered;

@property BOOL databasePropertiesDifferent;

@property (readonly) BOOL diffExists;
@property double differenceMeasure;

@end

NS_ASSUME_NONNULL_END
