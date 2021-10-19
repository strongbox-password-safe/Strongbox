//
//  ChaCha20OutputStream.h
//  Strongbox
//
//  Created by Strongbox on 08/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChaCha20OutputStream : NSOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream key:(NSData*)key iv:(NSData*)iv;

@end

NS_ASSUME_NONNULL_END
