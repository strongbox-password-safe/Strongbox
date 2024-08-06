//
//  SalesManager.m
//  Strongbox
//
//  Created by Strongbox on 13/04/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "SaleScheduleManager.h"
#import "MMcGPair.h"
#import "NSDate+Extensions.h"
#import "NSArray+Extensions.h"
#import "AppPreferences.h"

#import "Strongbox-Swift.h"

@interface SaleScheduleManager ()

@property NSArray<Sale*> *newerSchedule;
@property (readonly, nullable) Sale* saleAfterNextSale;

@end

@implementation SaleScheduleManager

+ (instancetype)sharedInstance {
    static SaleScheduleManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SaleScheduleManager alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.newerSchedule = Sale.schedule;
    }
    
    return self;
}

- (Sale*)currentSale {
    NSDate* now = NSDate.date;

    Sale* ret = [self.newerSchedule firstOrDefault:^BOOL(Sale * _Nonnull obj) {
        return [now isLaterThan:obj.start] && [now isEarlierThan:obj.end];
    }];

    return ret;
}

- (Sale*)saleAfterNextSale {
    NSDate* now = NSDate.date;
    
    NSUInteger idx = [self.newerSchedule indexOfFirstMatch:^BOOL(Sale* _Nonnull obj) {
        return [now isLaterThan:obj.start] && [now isEarlierThan:obj.end];
    }];
    
    if ( idx != NSNotFound ) {
        idx++;

        if ( idx < self.newerSchedule.count ) {
            return self.newerSchedule[idx];
        }
    }
    
    return nil;
}

- (NSDate *)saleAfterNextSaleStartDate {
    return self.saleAfterNextSale.start;
}

- (BOOL)saleNowOn {
    return self.currentSale != nil;
}

- (NSDate *)currentSaleEndDate {
    return self.currentSale.end;
}

- (BOOL)userHasBeenPromptedAboutCurrentSale {
    NSDate* now = NSDate.date;

    NSInteger idx = [self.newerSchedule indexOfFirstMatch:^BOOL(Sale* _Nonnull obj) {
        return [now isLaterThan:obj.start] && [now isEarlierThan:obj.end];
    }];
    
    if ( idx == NSNotFound ) {

        return YES;
    }

    NSInteger foo = AppPreferences.sharedInstance.promptedForSale;

    return foo >= idx;
}

- (void)setUserHasBeenPromptedAboutCurrentSale:(BOOL)userHasBeenPromptedAboutCurrentSale {
    NSDate* now = NSDate.date;

    NSInteger idx = [self.newerSchedule indexOfFirstMatch:^BOOL(Sale* _Nonnull obj) {
        return [now isLaterThan:obj.start] && [now isEarlierThan:obj.end];
    }];

    if ( idx == NSNotFound ) {
        slog(@"WARNWARN: No current sale to set as prompted");
        return;
    }

    AppPreferences.sharedInstance.promptedForSale = idx;
}

@end
