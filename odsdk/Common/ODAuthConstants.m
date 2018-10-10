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
#import "ODAuthConstants.h"

NSString * const OD_SDK_VERSION = @"1.1.2";

NSString * const OD_AUTH_ERROR_DOMAIN = @"com.microsoft.onedrivesdk.autherror";
NSString * const OD_AUTH_ERROR_KEY = @"ODAuthErrorKey";

NSString * const OD_API_HEADER_AUTHORIZATION = @"Authorization";
NSString * const OD_API_HEADER_CONTENTTYPE = @"Content-Type";
NSString * const OD_API_HEADER_CONTENTTYPE_FORMENCODED = @"application/x-www-form-urlencoded";
NSString * const OD_API_HEADER_APPLICATION_JSON = @"application/json";
NSString * const OD_API_HEADER_ACCEPT = @"accept";

NSString * const OD_MSA_TELEMTRY_HEADER = @"X-RequestStats";
NSString * const OD_AAD_TELEMTRY_HEADER = @"X-ClientService-ClientTag";

NSString * const OD_TELEMTRY_HEADER_VALUE_FORMAT = @"SDK-Version=iOS-v%@";

NSString * const OD_AUTH_ACCESS_TOKEN = @"access_token";
NSString * const OD_AUTH_CODE = @"code";
NSString * const OD_AUTH_DISPLAY = @"display";
NSString * const OD_AUTH_DISPLAY_IOS_PHONE = @"ios_phone";
NSString * const OD_AUTH_CLIENTID = @"client_id";
NSString * const OD_AUTH_EXPIRES = @"expires_in";
NSString * const OD_AUTH_GRANT_TYPE = @"grant_type";
NSString * const OD_AUTH_GRANT_TYPE_AUTHCODE = @"authorization_code";
NSString * const OD_AUTH_REDIRECT_URI = @"redirect_uri";
NSString * const OD_AUTH_REFRESH_TOKEN = @"refresh_token";
NSString * const OD_AUTH_RESPONSE_TYPE = @"response_type";
NSString * const OD_AUTH_SCOPE = @"scope";
NSString * const OD_AUTH_TOKEN = @"token";
NSString * const OD_AUTH_SECRET = @"client_secret";
NSString * const OD_AUTH_USER_ID = @"user_id";
NSString * const OD_AUTH_TOKEN_ID = @"id_token";
NSString * const OD_AUTH_USER_NAME = @"username";
NSString * const OD_AUTH_USER_EMAIL = @"user_email";



NSString * const OD_DISCOVERY_ACCOUNT_TYPE = @"account_type";
NSString * const OD_DISCOVERY_ACCOUNT_TYPE_AAD = @"AAD";
NSString * const OD_DISCOVERY_ACCOUNT_TYPE_MSA = @"MSA";
NSString * const OD_DISCOVERY_SERVICE_RESOURCEID = @"https://api.office.com/discovery/";
NSString * const OD_DISCOVERY_SERVICE_URL = @"https://api.office.com/discovery/v2.0/me/services";
NSString * const OD_DISAMBIGUATION_URL = @"https://onedrive.live.com/picker/accountchooser?load_login=false";

NSString * const OD_MICROSOFT_ACCOUNT_ENDPOINT_HOST = @"login.live.com";
NSString * const OD_MICROSOFT_ACCOUNT_AUTH_URL = @"https://login.live.com/oauth20_authorize.srf";
NSString * const OD_MICROSOFT_ACCOUNT_TOKEN_URL = @"https://login.live.com/oauth20_token.srf";
NSString * const OD_MICROSOFT_ACCOUNT_REDIRECT_URL = @"https://login.live.com/oauth20_desktop.srf";
NSString * const OD_MICROSOFT_ACCOUNT_LOGOUT_URL = @"https://login.live.com/oauth20_logout.srf";
NSString * const OD_DISCOVERY_REDIRECT_URL = @"https://localhost:5000";

NSString * const OD_MICROSOFT_ACCOUNT_ENDPOINT = @"https://api.onedrive.com";
NSString * const OD_MICROSOFT_ACCOUNT_API_VERSION = @"v1.0";

NSString * const OD_ACTIVE_DIRECTORY_AUTH_URL = @"https://login.microsoftonline.com/common/oauth2/token";
NSString * const OD_ACTIVE_DIRECTORY_AUTH_ENDPOINT_HOST = @"login.microsoftoneline.com";
NSString * const OD_ACTIVE_DIRECTORY_URL_SUFFIX = @"_api/v2.0/me";