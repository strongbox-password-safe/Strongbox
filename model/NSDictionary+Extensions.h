//
//  NSDictionary+Extensions.h
//  Strongbox
//
//  Created by Mark on 08/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (Extensions)

- (id)objectForCaseInsensitiveKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
