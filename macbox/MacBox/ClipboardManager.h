//
//  ClipboardManager.h
//  Strongbox
//
//  Created by Mark on 10/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClipboardManager : NSObject

+ (instancetype)sharedInstance;

- (void)copyConcealedString:(NSString *)string;
- (void)copyNoneConcealedString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
