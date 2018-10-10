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
#import "ODLoggerProtocol.h"

/**
 Simple Logger for the OneDriveSDK will log everything to the console using NSLog
 
 ## Writing to a File 
 
 If you wish to log to a file instead of the console, it is easiest to subclass the ODLogger and overload writeMessage:
 This method will have the constructed string passed into the [ODLogger logWithLevel:message:] method and passed it along
 to the writeMessage: method


 @see writeMessage:
 
 */
@interface ODLogger : NSObject <ODLogger>

/**
 Creates the logger with the given level
 @param level the level to create the logger with
 @see ODLogLevel
 */
- (instancetype)initWithLogLevel:(ODLogLevel)level;

/**
 The current log level
 Use setLogLevel to set the logLevel
 @see setLogLevel:
 */
@property (readonly) ODLogLevel logLevel;

/**
 Actually writes the full log message.  This will just call NSLog with the message.
 @param  message the message to log
 */
- (void)writeMessage:(NSString *)message;

@end
