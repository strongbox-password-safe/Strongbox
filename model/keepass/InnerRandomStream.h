//
//  InnerRandomStream.h
//  Strongbox
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol InnerRandomStream <NSObject>

@property (nonatomic, readonly) NSData* key;

- (NSData*)xor:(NSData*)ct;

@end

NS_ASSUME_NONNULL_END
