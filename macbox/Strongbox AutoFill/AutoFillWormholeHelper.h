//
//  AutoFillWormholeHelper.h
//  MacBox
//
//  Created by Strongbox on 19/10/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AutoFillWormholeHelper : NSObject

+ (instancetype _Nullable)sharedInstance;

- (void)postWormholeMessage:(NSString*)requestId
                 responseId:(NSString*)responseId
                    message:(NSDictionary<NSString*, id>*)message
                 completion:(void (^ _Nullable)(BOOL success, NSDictionary<NSString*, id>* _Nullable response))completion;

- (void)postWormholeMessage:(NSString*)requestId
                 responseId:(NSString*)responseId
                    message:(NSDictionary<NSString*, id>*)message
                    timeout:(CGFloat)timeout
                 completion:(void (^ _Nullable)(BOOL success, NSDictionary<NSString*, id>* _Nullable response))completion;

@end

NS_ASSUME_NONNULL_END
