//
//  Sha256OutputStream.h
//  Strongbox
//
//  Created by Strongbox on 26/06/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Sha256PassThroughOutputStream : NSOutputStream

- (instancetype)initToOutputStream:(NSOutputStream *)outputStream;

@property (readonly) NSData* digest; 
@property (readonly) NSUInteger length; 

@end

NS_ASSUME_NONNULL_END
