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

#import <Foundation/Foundation.h>

/**
 *  LogLevels for the logger.
 */
typedef NS_ENUM(NSInteger, ODLogLevel){
    ODLogError = 0,
    ODLogWarn,
    ODLogInfo,
    ODLogDebug,
    ODLogVerbose
};

/**
 `ODLogger` is a protocol to use for simple logging.
 
 ## Usage
 
 The logger should only log messages when they are at the same level or below the level of the logger.
 
        [logger setLogLevel:ODLogInfo];
        [logger logWithLevel:ODLogWarn message:@"This should get logged"]; // logs " OneDriveSDK WARNING: This should get logged"
        [logger logWithLevel:ODLogVerbose message:@"This won't get logged"]; // doesn't log anything because Verbose is higher than Info
        [logger logWithLevel:ODLogError message:@"Print the error object : %@", error]; //logs and prints the error object
 

 */
@protocol ODLogger <NSObject>

/**
 Sets the logging level of the logger.
 @param logLevel The level to start logging.
 @see ODLogLevel
 */
- (void)setLogLevel:(ODLogLevel)logLevel;

/**
 Logs the message at the current level.
 @param level The level to log the message at @see ODLogLevel.
 @param messageFormat A string or format string and objects for the format string.
 @warning You should only log messages if the logLevel of the logger is set to that level or below.
 */
- (void)logWithLevel:(ODLogLevel)level message:(NSString *)messageFormat, ...;

@end
