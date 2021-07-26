//
//  SalesManager.h
//  Strongbox
//
//  Created by Strongbox on 13/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SaleScheduleManager : NSObject

+ (instancetype)sharedInstance;

@property (readonly) BOOL saleNowOn;
@property BOOL userHasBeenPromptedAboutCurrentSale;
@property (readonly, nullable) NSDate* currentSaleEndDate;

@end

NS_ASSUME_NONNULL_END
