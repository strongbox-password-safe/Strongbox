//
//  Kdbx4Document.m
//  Strongbox
//
//  Created by Mark on 17/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Kdbx4Document.h"

@implementation Kdbx4Document

- (instancetype)init
{
    self.format = kKeePass4;
    
    return [super init];
}

@end
