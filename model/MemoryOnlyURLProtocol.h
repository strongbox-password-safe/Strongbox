//
//  MemoryOnlyURLProtocol.h
//  Strongbox
//
//  Created by Strongbox on 04/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MemoryOnlyURLProtocol : NSURLProtocol {
}

+ (NSString*)memoryOnlyURLProtocolScheme;
+ (void)registerMemoryOnlyURLProtocol;

@end

NS_ASSUME_NONNULL_END
