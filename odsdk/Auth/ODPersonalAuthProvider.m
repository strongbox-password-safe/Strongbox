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


#import "ODPersonalAuthProvider.h"
#import "ODServiceInfo.h"
#import "ODAuthProvider+Protected.h"
#import "ODAuthConstants.h"
#import "ODAuthHelper.h"

@implementation ODPersonalAuthProvider

- (NSError *)errorFromURL:(NSURL *)url
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[OD_AUTH_ERROR_KEY] = url;
    return [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODServiceError userInfo:userInfo];
}

- (NSDictionary *)authRequestParameters
{
    return @{ OD_AUTH_CLIENTID : self.serviceInfo.appId,
              OD_AUTH_RESPONSE_TYPE : OD_AUTH_CODE,
              OD_AUTH_REDIRECT_URI : self.serviceInfo.redirectURL,
              OD_AUTH_SCOPE : [self.serviceInfo.scopes componentsJoinedByString:@","],
              OD_AUTH_DISPLAY : OD_AUTH_DISPLAY_IOS_PHONE
            };
}

- (NSURL *)authURL
{
    return [self authRequest].URL;
}

- (NSURLRequest *)authRequest
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:[self authRequestParameters]];
    parameters[OD_AUTH_USER_NAME] = self.serviceInfo.userEmail;
    return [ODAuthHelper requestWithMethod:@"GET" URL:[NSURL URLWithString:self.serviceInfo.authorityURL] parameters:parameters headers:nil];
}

- (NSDictionary *)tokenRequestParametersWithCode:(NSString *)code
{
    return @{ OD_AUTH_CLIENTID : self.serviceInfo.appId,
              OD_AUTH_CODE : code,
              OD_AUTH_REDIRECT_URI : self.serviceInfo.redirectURL,
              OD_AUTH_GRANT_TYPE: OD_AUTH_GRANT_TYPE_AUTHCODE
            };
}

- (NSURLRequest *)tokenRequestWithCode:(NSString *)code
{
    if (code){
        return [self tokenRequestWithParameters:[self tokenRequestParametersWithCode:code]];
    }
    return nil;
}

- (NSDictionary *)refreshRequestParametersWithRefreshToken:(NSString *)refreshToken;
{
    return @{ OD_AUTH_CLIENTID : self.serviceInfo.appId,
              OD_AUTH_REFRESH_TOKEN : refreshToken,
              OD_AUTH_GRANT_TYPE : OD_AUTH_REFRESH_TOKEN
            };
}

- (NSURLRequest *)tokenRequestWithParameters:(NSDictionary *)params
{
    
    return [ODAuthHelper requestWithMethod:@"POST"
                                       URL:[NSURL URLWithString:self.serviceInfo.tokenURL]
                                parameters:params
                                   headers:@{OD_API_HEADER_CONTENTTYPE :OD_API_HEADER_CONTENTTYPE_FORMENCODED}];
}


- (NSURLRequest *)refreshRequestWithRefreshToken:(NSString *)refreshToken
{
    if (refreshToken){
        return [self tokenRequestWithParameters:[self refreshRequestParametersWithRefreshToken:refreshToken]];
    }
    return nil;
}

- (NSDictionary *)logoutRequestParameters
{
    return @{ OD_AUTH_CLIENTID : self.serviceInfo.appId,
              OD_AUTH_REDIRECT_URI : self.serviceInfo.redirectURL };
}

- (NSURLRequest *)logoutRequest
{
    NSURLRequest *request = nil;
    if (self.serviceInfo.logoutURL){
        request = [ODAuthHelper requestWithMethod:@"GET"
                                              URL:[NSURL URLWithString:self.serviceInfo.logoutURL]
                                       parameters:[self logoutRequestParameters]
                                          headers:nil];
    }
    return request;
}

- (NSString *)telemtryHeaderField
{
    return [OD_MSA_TELEMTRY_HEADER copy];
}

@end
