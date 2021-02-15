//
//  StringValue.h
//  Strongbox
//
//  Created by Mark on 27/03/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StringValue : NSObject

+ (instancetype)valueWithString:(NSString *)string;
+ (instancetype)valueWithString:(NSString*)string protected:(BOOL)protected;

@property NSString* value;
@property BOOL protected;

@end

NS_ASSUME_NONNULL_END
