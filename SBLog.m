//
//  slog.m
//  MacBox
//
//  Created by Strongbox on 22/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "SBLog.h"
#import "NSDate+Extensions.h"

void SBLogActual( NSString* fmt, ... ) {
    va_list argptr;
    va_start(argptr,fmt);
    NSString* msg = [[NSString alloc] initWithFormat:fmt arguments:argptr];
    NSLog(@"%@[%@] %@", NSThread.isMainThread ? @"M" : @"N", NSDate.date.iso8601DateStringWithFractionalSeconds, msg);


    va_end(argptr);
}
