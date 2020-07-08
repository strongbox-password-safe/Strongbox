//
//  AesOutputStream.h
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AesOutputStream : NSOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream encrypt:(BOOL)encrypt key:(NSData*)key iv:(NSData*)iv;

@end

NS_ASSUME_NONNULL_END
