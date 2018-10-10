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


#import "ODTestCase.h"
#import "ODLogger.h"


@interface MockLogger : ODLogger

- (void)writeMessage:(NSString *)message;

@property NSString *message;

@end

@implementation MockLogger

- (void)writeMessage:(NSString *)message
{
    self.message = message;
}

@end

@interface ODLoggerTests : ODTestCase

@property ODLogger *mockLogger;

@end

@implementation ODLoggerTests

- (void)setUp {
    [super setUp];
    self.mockLogger = OCMPartialMock([[ODLogger alloc] initWithLogLevel:ODLogError]);
}

- (void)testLogError {
    [self verifyLogWithMessage:@"foo" level:ODLogError shouldCallWriteMessage:YES];
}

- (void)testLogInfoNoLog{
    [self verifyLogWithMessage:@"foo" level:ODLogInfo shouldCallWriteMessage:NO];
}

- (void)testLogWarnNoLog{
    [self verifyLogWithMessage:@"foo" level:ODLogWarn shouldCallWriteMessage:NO];
}

- (void)testLogVerboseNoLog{
    [self.mockLogger setLogLevel:ODLogWarn];
    [self verifyLogWithMessage:@"foo" level:ODLogVerbose shouldCallWriteMessage:NO];
}

- (void)testLogVerboseWithLog{
    [self.mockLogger setLogLevel:ODLogVerbose];
    [self verifyLogWithMessage:@"foo" level:ODLogVerbose shouldCallWriteMessage:YES];
}

- (void)testLogVerboseLogWarn{
    [self.mockLogger setLogLevel:ODLogVerbose];
    [self verifyLogWithMessage:@"foo" level:ODLogWarn shouldCallWriteMessage:YES];
}

- (void)testVarArgsObject{
 
    MockLogger *mockLogger = [[MockLogger alloc] initWithLogLevel:ODLogError];
    [mockLogger logWithLevel:ODLogError message:@"FOo bar baz %@", @"qux", nil];
    
    XCTAssertTrue([mockLogger.message containsString:@"qux"]);
}

- (void)testVarArgsNumber{
    MockLogger *mockLogger = [[MockLogger alloc] initWithLogLevel:ODLogError];
    [mockLogger logWithLevel:ODLogError message:@"FOo Bar baz %ld", 42, nil];
    
    XCTAssertTrue([mockLogger.message containsString:@"42"]);
}

- (void)verifyLogWithMessage:(NSString *)message
                       level:(ODLogLevel)logLevel
      shouldCallWriteMessage:(BOOL)callWriteMessage
{
    NSString *expectedMessage = message;
    NSString *receivedMessage = nil;
    BOOL calledWriteMessage = NO;
    [self mockWriteMessageWithLogger:self.mockLogger message:&receivedMessage calledWriteMessage:&calledWriteMessage];
    
    [self.mockLogger logWithLevel:logLevel message:message];
    
    XCTAssertEqual(calledWriteMessage, callWriteMessage);
    if (calledWriteMessage){
        XCTAssertTrue([receivedMessage containsString:[self levelStringWithLevel:logLevel]]);
        XCTAssertTrue([receivedMessage containsString:expectedMessage]);
    }
    
}

- (void)mockWriteMessageWithLogger:(id)logger
                           message:(NSString * __strong *)fullMessage
                calledWriteMessage:(BOOL *)calledWriteMessage
{
    OCMStub([logger writeMessage:[OCMArg any]]).andDo(^(NSInvocation *invocation){
        NSString *receivedMessage = nil;
        [invocation getArgument:&receivedMessage atIndex:2];
        if (fullMessage && receivedMessage){
            *fullMessage = receivedMessage;
        }
        if (calledWriteMessage){
            *calledWriteMessage = YES;
        }
    });
}

- (NSString *)levelStringWithLevel:(ODLogLevel)logLevel
{
    NSString *logLevelString = nil;
    switch (logLevel) {
        case ODLogError:
            logLevelString = @"ERROR :";
            break;
        case ODLogWarn:
            logLevelString = @"WARNING :";
            break;
        case ODLogInfo:
            logLevelString = @"INFO :";
            break;
        case ODLogDebug:
            logLevelString = @"DEBUG : ";
            break;
        case ODLogVerbose:
            logLevelString = @"VERBOSE :";
            break;
        default:
            break;
    }
    return logLevelString;
}

@end
