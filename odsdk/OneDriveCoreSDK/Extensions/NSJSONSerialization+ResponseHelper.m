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


#import "NSJSONSerialization+ResponseHelper.h"
#import "ODConstants.h"
#import "ODError.h"

@implementation NSJSONSerialization (ResponseHelper)

+ (NSDictionary *)dictionaryWithResponse:(NSURLResponse *)response responseData:(NSData *)data error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(response);
    
    NSDictionary *responseDictionary = nil;
    NSError *parseError = nil;
    NSInteger statusCode = ((NSHTTPURLResponse*)response).statusCode;
    
    //make sure we don't try and parse bad nothing
    if (data && [data bytes]){
        responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&parseError];
    }
    // if there was a parse error and the caller wants the error to be set
    if (parseError && error){
        *error = parseError;
    }
    // try and parse the client error
    else if ((statusCode < 200 || statusCode > 299) && error) {
        *error = [NSJSONSerialization errorWithStatusCode:statusCode responseDictionary:responseDictionary];
    }
    // if an error occurred we shouldn't return the json response
    if (error && *error){
        responseDictionary = nil;
    }
    
    return responseDictionary;
}

+ (NSError *)errorWithStatusCode:(NSInteger)statusCode responseDictionary:(NSDictionary *)responseDictionary
{
    NSParameterAssert(statusCode);
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = [NSHTTPURLResponse localizedStringForStatusCode:(NSInteger)statusCode];
    ODError *responseError = nil;
    if (responseDictionary){
        responseError = [ODError errorWithDictionary:responseDictionary[ODErrorKey]];
    }
    if (responseError){
        userInfo[ODErrorKey] = responseError;
    }
    return [NSError errorWithDomain:ODErrorDomain code:statusCode userInfo:userInfo];
}

+ (NSError *)errorFromResponse:(NSURLResponse *)response responseObject:(NSDictionary *)responseObject
{
    NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
    if (statusCode < 200 || statusCode > 299){
        return [NSJSONSerialization errorWithStatusCode:statusCode responseDictionary:@{}];
    }
    return nil;
}

@end
