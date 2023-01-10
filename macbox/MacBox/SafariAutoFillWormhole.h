//
//  SafariAutoFillWormhole.h
//  MacBox
//
//  Created by Strongbox on 07/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafariAutoFillWormhole : NSObject

+ (instancetype _Nullable)sharedInstance;

- (void)listenToAutoFillWormhole;
- (void)cleanupWormhole;

@end

NS_ASSUME_NONNULL_END
