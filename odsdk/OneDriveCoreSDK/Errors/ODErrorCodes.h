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

#ifndef OneDriveSDK_ODErrorCodes_h
#define OneDriveSDK_ODErrorCodes_h

/**
 Error codes returned from the service
 @see https://github.com/OneDrive/onedrive-api-docs/blob/master/misc/errors.md for a more detailed description of errors
 */

extern NSString *const ODAccessDeniedError;
extern NSString *const ODActivityLimitReachedError;
extern NSString *const ODGeneralExceptionError;
extern NSString *const ODInvalidRangeError;
extern NSString *const ODInvalidRequestError;
extern NSString *const ODItemNotFoundError;
extern NSString *const ODMalwareDetectedError;
extern NSString *const ODNameAlreadyExistsError;
extern NSString *const ODNotAllowedError;
extern NSString *const ODNotSupportedError;
extern NSString *const ODResourceModifiedError;
extern NSString *const ODResyncRequiredError;
extern NSString *const ODServiceNotAvailableError;
extern NSString *const ODQuotaLimitReacherError;
extern NSString *const ODUnAuthenticatedError;

extern NSString *const ODMalformedErrorResponseError;

#endif
