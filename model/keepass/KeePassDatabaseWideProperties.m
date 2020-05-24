//
//  KeePassDatabaseWideProperties.m
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "KeePassDatabaseWideProperties.h"

@implementation KeePassDatabaseWideProperties

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.customIcons = @{};
        self.deletedObjects = @{};
    }
    return self;
}
@end
