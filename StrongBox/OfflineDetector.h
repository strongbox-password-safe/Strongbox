//
//  OfflineDetector.h
//  Strongbox-iOS
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OfflineDetector : NSObject

+ (instancetype)sharedInstance;

- (void) stopMonitoringConnectivitity;
- (void) startMonitoringConnectivitity;
- (BOOL) isOffline;

@end

NS_ASSUME_NONNULL_END
