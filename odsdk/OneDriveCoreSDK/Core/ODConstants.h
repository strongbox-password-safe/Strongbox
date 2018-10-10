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

#ifndef OneDriveSDK_ODConstants_h
#define OneDriveSDK_ODConstants_h

typedef NS_ENUM(NSInteger, ODClientErrorCode){
    ODBadRequest                  = 400,
    ODUnauthorized                = 401,
    ODForbidden                   = 403,
    ODNotFound                    = 404,
    ODMethodNotAllowed            = 405,
    ODUNACCEPTABLE                = 406,
    ODConflict                    = 409,
    ODLengthRequired              = 411,
    ODPreconditionFailed          = 412,
    ODRequestEntityTooLarge       = 413,
    ODUnsupportedMediaType        = 415,
    ODRequestRangeNotSatisfiable  = 416,
    ODUnprocessableEntity         = 422,
    ODTooManyRequests             = 429,
    ODInternalServerError         = 500,
    ODNotImplemented              = 501,
    ODServiceUnavailable          = 503,
    ODInsufficientStorage         = 507,
    ODUnknownError                 = 999,
};

typedef NS_ENUM(NSInteger, ODExpectedResponseCodes){
    ODOK = 200,
    ODCreated = 201,
    ODAccepted = 202,
    ODPartialContent = 206,
    ODNotModified = 304,
};

extern NSString *const ODErrorDomain;
extern NSString *const ODErrorKey;
extern NSString *const ODHttpFailingResponseKey;
extern NSString *const ODODataNextContext;
extern NSString *const ODCollectionValueKey;


extern NSString *const ODHeaderLocation;
extern NSString *const ODHeaderPrefer;
extern NSString *const ODHeaderContentType;
extern NSString *const ODHeaderApplicationJson;
extern NSString *const ODHeaderRespondAsync;

#endif
