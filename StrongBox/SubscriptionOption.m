//
//  SubscriptionOption.m
//  Strongbox-iOS
//
//  Created by Mark on 04/02/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "SubscriptionOption.h"

@implementation SubscriptionOption

- (instancetype)initWithProduct:(SKProduct *)product {
    if(self = [super init]) {
        self.storeKitProduct = product;
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Product: [%@]", self.storeKitProduct];
}

@end
