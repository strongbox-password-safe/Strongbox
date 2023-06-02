//
//  AutoFillProxyServer.h
//  MacBox
//
//  Created by Strongbox on 14/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillProxyServer : NSObject

+ (instancetype)sharedInstance;

@property (readonly) BOOL isRunning;

- (void)stop;
- (BOOL)start;

@end

NS_ASSUME_NONNULL_END
