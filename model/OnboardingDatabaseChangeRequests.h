//
//  OnboardingDatabaseChangeRequests.h
//  Strongbox
//
//  Created by Strongbox on 09/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OnboardingDatabaseChangeRequests : NSObject

@property BOOL updateDatabaseToV4OnLoad;
@property BOOL reduceArgon2MemoryOnLoad;

@end

NS_ASSUME_NONNULL_END
