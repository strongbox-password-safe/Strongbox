//
//  GZIPCompressOutputStream.h
//  Strongbox
//
//  Created by Strongbox on 07/09/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GZIPCompressOutputStream : NSOutputStream

- (instancetype)initToOutputStream:(NSOutputStream*)outputStream;

@end

NS_ASSUME_NONNULL_END
