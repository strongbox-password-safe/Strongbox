//
//  Settings.h
//  MacBox
//
//  Created by Mark on 15/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Settings : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic) BOOL revealDetailsImmediately;
@property (nonatomic) BOOL fullVersion;

@property (nonatomic, readonly) BOOL freeTrial;
@property (nonatomic, readonly) NSInteger freeTrialDaysRemaining;

@property (nonatomic, strong) NSDate* endFreeTrialDate;

@end
