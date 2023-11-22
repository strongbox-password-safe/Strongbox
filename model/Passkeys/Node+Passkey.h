//
//  NodePasskey.h
//  Strongbox
//
//  Created by Strongbox on 03/09/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@class Passkey;

@interface Node (Passkey)
 
@property (nullable) Passkey* passkey; 

@end

NS_ASSUME_NONNULL_END
