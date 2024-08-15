//
//  PlaintextInnerStream.h
//  Strongbox
//
//  Created by Strongbox on 31/10/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InnerRandomStream.h"

NS_ASSUME_NONNULL_BEGIN

@interface PlaintextInnerStream : NSObject<InnerRandomStream>

@property (nonatomic, readonly) NSData* key;

- (NSData*)doTheXor:(NSData*)ct;

@end

NS_ASSUME_NONNULL_END
