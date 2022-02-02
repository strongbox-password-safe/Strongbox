//
//  DuressActionHelper.h
//  Strongbox
//
//  Created by Strongbox on 08/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DatabaseUnlocker.h"

NS_ASSUME_NONNULL_BEGIN

@interface DuressActionHelper : NSObject

+ (void)performDuressAction:(UIViewController*)viewController database:(DatabasePreferences*)database isAutoFillOpen:(BOOL)isAutoFillOpen completion:(UnlockDatabaseCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END
