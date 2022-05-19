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

@interface SaleScheduleManager ()

@property NSArray<MMcGPair<NSDate*, NSDate*>*> *schedule;
@property (readonly, nullable) MMcGPair<NSDate*, NSDate*>* currentSale;

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
        
        
        
        
        
        self.schedule = @[
            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2021-11-26"]
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2021-11-30"]], 
            
            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2021-12-24"]
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2021-12-27"]], 
            
            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-03-17"]
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-03-21"]], 
            
            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-06-03"]
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-06-07"]], 

            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-09-02"]
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-09-05"]], 
            
            [MMcGPair pairOfA:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-11-25"]   
                         andB:[NSDate fromYYYY_MM_DD_London_Noon_Time_String:@"2022-11-29"]],
            
            
        ];
    }
    
    return self;
}

- (MMcGPair<NSDate*, NSDate*>*)currentSale {
    NSDate* now = NSDate.date;
    
    MMcGPair<NSDate*, NSDate*>* ret = [self.schedule firstOrDefault:^BOOL(MMcGPair<NSDate *,NSDate *> * _Nonnull obj) {
        return [now isLaterThan:obj.a] && [now isEarlierThan:obj.b];
    }];
    
    return ret;
}

- (BOOL)saleNowOn {
    return self.currentSale != nil;
}

- (NSDate *)currentSaleEndDate {
    return self.currentSale.b;
}

- (BOOL)userHasBeenPromptedAboutCurrentSale {
    NSDate* now = NSDate.date;

    NSInteger idx = [self.schedule indexOfFirstMatch:^BOOL(MMcGPair<NSDate *,NSDate *> * _Nonnull obj) {
        return [now isLaterThan:obj.a] && [now isEarlierThan:obj.b];
    }];
    
    if ( idx == NSNotFound ) {

        return YES;
    }

    NSInteger foo = AppPreferences.sharedInstance.promptedForSale;

    return foo >= idx;
}

- (void)setUserHasBeenPromptedAboutCurrentSale:(BOOL)userHasBeenPromptedAboutCurrentSale {
    NSDate* now = NSDate.date;

    NSInteger idx = [self.schedule indexOfFirstMatch:^BOOL(MMcGPair<NSDate *,NSDate *> * _Nonnull obj) {
        return [now isLaterThan:obj.a] && [now isEarlierThan:obj.b];
    }];

    if ( idx == NSNotFound ) {
        NSLog(@"WARNWARN: No current sale to set as prompted");
        return;
    }

    AppPreferences.sharedInstance.promptedForSale = idx;
}

@end
