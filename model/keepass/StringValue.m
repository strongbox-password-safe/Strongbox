//
//  StringValue.m
//  Strongbox
//
//  Created by Mark on 27/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "StringValue.h"

@implementation StringValue

+ (instancetype)valueWithString:(NSString *)string {
    return [StringValue valueWithString:string protected:NO];
}

+ (instancetype)valueWithString:(NSString *)string protected:(BOOL)protected {
    StringValue* ret = [[StringValue alloc] init];
    
    ret.value = string;
    ret.protected = protected;
    
    return ret;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@%@", self.value, self.protected ? @" <Protected=True>" : @""];
}
@end
