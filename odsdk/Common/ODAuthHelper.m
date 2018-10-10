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


#import "ODAuthHelper.h"
#import "ODAccountSession.h"
#import "ODAuthConstants.h"
#import "ODServiceInfo.h"

@implementation ODAuthHelper

+ (NSURLRequest *)requestWithMethod:(NSString *)method URL:(NSURL *)url parameters:(NSDictionary *)params headers:(NSDictionary *)headers
{
    NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *paramString = nil;
    if (params){
        paramString = [ODAuthHelper encodeQueryParameters:params];
    }
    NSMutableURLRequest *request = nil;
    if ([method isEqualToString:@"GET"]){
        urlComponents.query = paramString;
        request = [NSMutableURLRequest requestWithURL:urlComponents.URL];
    }
    else if ([method isEqualToString:@"POST"]){
        request = [NSMutableURLRequest requestWithURL:urlComponents.URL];
        request.HTTPMethod = method;
        request.HTTPBody = (paramString) ? [paramString dataUsingEncoding:NSUTF8StringEncoding] : nil;
    }
    if (headers){
        [headers enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop){
            [request setValue:value forHTTPHeaderField:key];
        }];
    }
    return request;
    
}

+ (ODAccountSession *)accountSessionWithResponse:(NSDictionary *)session
                                     serviceInfo:(ODServiceInfo *)serviceInfo;
{
    NSParameterAssert(serviceInfo);
    NSParameterAssert(session);
    
    NSDate *expires = [NSDate dateWithTimeIntervalSinceNow:[session[OD_AUTH_EXPIRES] doubleValue]];
    NSString *accountId = session[OD_AUTH_USER_ID];
    // Active Directory obfuscates the id and calls it id_token
    if (!accountId){
        accountId = session[OD_AUTH_TOKEN_ID];
    }
    if (accountId && expires){
        return [[ODAccountSession alloc] initWithId:accountId
                                        accessToken:session[OD_AUTH_ACCESS_TOKEN]
                                            expires:expires
                                       refreshToken:session[OD_AUTH_REFRESH_TOKEN]
                                        serviceInfo:serviceInfo];
    }
    return nil;
}

+ (NSString *)codeFromCodeFlowRedirectURL:(NSURL *)url
{
    NSDictionary *queryParams = [ODAuthHelper decodeQueryParameters:url];
    return queryParams[OD_AUTH_CODE];
}

+ (NSDictionary *) decodeQueryParameters:(NSURL*)url
{
    NSParameterAssert(url);
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if(url.query != nil && url.query.length > 0)
    {
        NSArray *queryItems = [url.query componentsSeparatedByString:@"&"];
        for(NSString *queryItem in queryItems)
        {
            NSArray *keyValuePair = [queryItem componentsSeparatedByString:@"="];
            if(keyValuePair.count == 2)
            {
                NSString *key = [keyValuePair objectAtIndex:0];
                key = [key stringByReplacingOccurrencesOfString:@"+" withString:@" "];
                key = [key stringByRemovingPercentEncoding];
                
                NSString *value = [keyValuePair objectAtIndex:1];
                value = [value stringByReplacingOccurrencesOfString:@"+" withString:@" "];
                value = [value stringByRemovingPercentEncoding];

                params[key] = value;
            }
        }
    }
    return params;
}

+ (NSString *)encodeQueryParameters:(NSDictionary *)params
{
    NSParameterAssert(params);
    
    NSMutableString *queryParams = [NSMutableString string];
    for(NSString *key in params.allKeys)
    {
        [queryParams appendFormat:@"&%@=%@", key, params[key]];
    }
    
    // Remove first '&'
    if(queryParams.length > 0) {
        [queryParams deleteCharactersInRange:NSMakeRange(0, 1)];
    }
    
    return queryParams;
}

+ (BOOL)shouldRefreshSession:(ODAccountSession *)session
{
    BOOL shouldRefresh = NO;
    shouldRefresh = session.refreshToken && ([session.expires timeIntervalSinceNow] < 30);
    return shouldRefresh;
}

+ (void)appendAuthHeaders:(NSMutableURLRequest *)request token:(NSString *)token
{
    [request setValue:[NSString stringWithFormat:@"bearer %@", token] forHTTPHeaderField:OD_API_HEADER_AUTHORIZATION];
}

+ (NSDictionary *)sessionDictionaryWithResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError * __autoreleasing *)error;
{
    NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
    NSDictionary *authResponse = nil;
    NSError *parseError = nil;
    if (data && [data bytes]){
        authResponse = [NSJSONSerialization JSONObjectWithData:data options:NSUTF8StringEncoding error:&parseError];
    }
    // if the status wasn't 200 there was an error with the authority
    if (status == 200){
        if (parseError && error){
            *error = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODSerializationError userInfo:@{ OD_AUTH_ERROR_KEY : parseError }];
        }
    }
    else if (error){
        NSDictionary *userInfo = @{ OD_AUTH_ERROR_KEY : @(status),
                                    NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:status] };
        *error = [NSError errorWithDomain:OD_AUTH_ERROR_DOMAIN code:ODServiceError userInfo:userInfo];
    }
    return authResponse;
}

@end
