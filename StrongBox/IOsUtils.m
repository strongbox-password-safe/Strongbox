//
//  Utils.m
//  StrongBox
//
//  Created by Mark McGuill on 19/08/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <UIKit/UIKit.h>

@implementation IOsUtils

// https://stackoverflow.com/questions/8261961/better-way-to-get-the-users-name-from-device

+ (NSString*)nameFromDeviceName {
    return [[IOsUtils nameFromDeviceName:[[UIDevice currentDevice] name]] componentsJoinedByString:@" "];
}

+(NSArray *)nameFromDeviceName:(NSString *)deviceName
{
    NSError * error;
    static NSString * expression = (@"^(?:iPhone|phone|iPad|iPod)\\s+(?:de\\s+)?|"
                                    "(\\S+?)(?:['’]?s)?(?:\\s+(?:iPhone|phone|iPad|iPod))?$|"
                                    "(\\S+?)(?:['’]?的)?(?:\\s*(?:iPhone|phone|iPad|iPod))?$|"
                                    "(\\S+)\\s+");
    static NSRange RangeNotFound = (NSRange){.location=NSNotFound, .length=0};
    NSRegularExpression * regex = [NSRegularExpression regularExpressionWithPattern:expression
                                                                            options:(NSRegularExpressionCaseInsensitive)
                                                                              error:&error];
    NSMutableArray * name = [NSMutableArray new];
    for (NSTextCheckingResult * result in [regex matchesInString:deviceName
                                                         options:0
                                                           range:NSMakeRange(0, deviceName.length)]) {
        for (int i = 1; i < result.numberOfRanges; i++) {
            if (! NSEqualRanges([result rangeAtIndex:i], RangeNotFound)) {
                [name addObject:[deviceName substringWithRange:[result rangeAtIndex:i]].capitalizedString];
            }
        }
    }
    return name;
}

@end
