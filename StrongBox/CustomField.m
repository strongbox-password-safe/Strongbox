//
//  CustomField.m
//  Strongbox
//
//  Created by Mark on 26/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "CustomField.h"

@implementation CustomField

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@] = [%@] Protected=[%@]", self.key, self.value, self.protected ? @"YES" : @"NO"];
}
@end
