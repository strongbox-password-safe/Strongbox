//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "ODLogger.h"
#include <stdarg.h>

@implementation ODLogger


- (instancetype)initWithLogLevel:(ODLogLevel)level
{
    self = [super init];
    if (self){
        _logLevel = level;
    }
    return self;
}

- (void)setLogLevel:(ODLogLevel)logLevel
{
    _logLevel = logLevel;
}

- (void)logWithLevel:(ODLogLevel)level message:(NSString *)messageFormat, ...
{
    if (level <= self.logLevel){
        va_list args;
        va_start(args, messageFormat);
        NSString *logLevel = nil;
        switch (level) {
            case ODLogError:
                logLevel = @"ERROR :";
                break;
            case ODLogWarn:
                logLevel = @"WARNING :";
                break;
            case ODLogInfo:
                logLevel = @"INFO :";
                break;
            case ODLogDebug:
                logLevel = @"DEBUG : ";
                break;
            case ODLogVerbose:
                logLevel = @"VERBOSE :";
                break;
            default:
                break;
        }
        NSString *message = nil;
        if (messageFormat){
            NSString *stringFormat = [NSString stringWithFormat:@"OneDrive SDK %@ %@", logLevel, messageFormat];
           message = [[NSString alloc] initWithFormat:stringFormat arguments:args];
        }
        [self writeMessage:message];
        va_end(args);
    }
}

- (void)writeMessage:(NSString *)message
{
    NSLog(@"%@", message);
}
@end
