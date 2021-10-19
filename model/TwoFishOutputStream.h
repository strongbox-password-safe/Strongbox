//
//  TwoFishOutputStream.h
//  Strongbox
//
//  Created by Strongbox on 09/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TwoFishOutputStream : NSOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream key:(NSData*)key iv:(NSData*)iv;

@end

NS_ASSUME_NONNULL_END
