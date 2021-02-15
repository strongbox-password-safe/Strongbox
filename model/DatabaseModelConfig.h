//
//  DatabaseModelConfig.h
//  MacBox
//
//  Created by Strongbox on 15/06/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseModelConfig : NSObject

+ (instancetype)defaults;
+ (instancetype)withSanityCheckInnerStream:(BOOL)sanityCheckInnerStream;

@property (readonly) BOOL sanityCheckInnerStream;

@end

NS_ASSUME_NONNULL_END
