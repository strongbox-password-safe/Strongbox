//
//  StorageBrowserItem.m
//  StrongBox
//
//  Created by Mark on 26/05/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "StorageBrowserItem.h"

@implementation StorageBrowserItem

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ [folder: %d] - providerData = [%@]", self.name, self.folder, self.providerData];
}

@end
