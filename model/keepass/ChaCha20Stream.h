//
//  ChaCha20Stream.h
//  Strongbox
//
//  Created by Mark on 30/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "InnerRandomStream.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChaCha20Stream : NSObject<InnerRandomStream>

-(id)init NS_UNAVAILABLE;
- (id)initWithKey:(const NSData *)key;

- (NSData *)xor:(NSData *)ct;
@property (nonatomic, readonly) NSData* key;

@end

NS_ASSUME_NONNULL_END
