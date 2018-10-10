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
#import "ODServiceInfoProvider.h"
#import "ODServiceInfo.h"
#import "ODAppConfiguration.h"

@interface ODServiceInfoProvider()

- (ODServiceInfo *)serviceInfoFromDiscoveryResponse:(NSURL *)url appConfig:(ODAppConfiguration *)appConfig error:(NSError * __autoreleasing *)error;

@end

@interface ODServiceInfoProviderTests : ODTestCase

@property ODServiceInfoProvider *serviceInfoProvider;

@end

@implementation ODServiceInfoProviderTests

- (void)setUp {
    [super setUp];
    self.serviceInfoProvider = [[ODServiceInfoProvider alloc] init];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testGetMSAServiceInfo{
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.microsoftAccountAppId = @"foo";
    appconfig.microsoftAccountScopes = @[];
    
    [self.serviceInfoProvider getServiceInfoWithViewController:[[UIViewController alloc] init]
                                              appConfiguration:appconfig
                                                    completion:^(UIViewController *vc, ODServiceInfo *serviceInfo, NSError *error){
                                                        XCTAssertNil(error);
                                                        XCTAssertEqual(serviceInfo.accountType, ODMSAAccount);
                                                    }];
}

- (void)testGetAADServiceInfoNoResourceId{
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.activeDirectoryAppId = @"foo";
    appconfig.activeDirectoryRedirectURL = @"bar";
    
    [self.serviceInfoProvider getServiceInfoWithViewController:[[UIViewController alloc] init]
                                              appConfiguration:appconfig
                                                    completion:^(UIViewController *vc, ODServiceInfo *serviceInfo, NSError *error){
                                                        XCTAssertNil(error);
                                                        XCTAssertEqual(serviceInfo.accountType, ODADAccount);
                                                        XCTAssertEqual(serviceInfo.resourceId, OD_DISCOVERY_SERVICE_RESOURCEID);
                                                    }];   
}

- (void)testGetAADServiceInfoResourceId{
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.activeDirectoryAppId = @"foo";
    appconfig.activeDirectoryRedirectURL = @"bar";
    appconfig.activeDirectoryResourceId = @"quz";
    appconfig.activeDirectoryApiEndpointURL = @"quxx";
    
    [self.serviceInfoProvider getServiceInfoWithViewController:[[UIViewController alloc] init]
                                              appConfiguration:appconfig
                                                    completion:^(UIViewController *vc, ODServiceInfo *serviceInfo, NSError *error){
                                                        XCTAssertNil(error);
                                                        XCTAssertEqual(serviceInfo.accountType, ODADAccount);
                                                        XCTAssertEqual(serviceInfo.resourceId, appconfig.activeDirectoryResourceId);
                                                        XCTAssertEqual(serviceInfo.apiEndpoint, appconfig.activeDirectoryApiEndpointURL);
                                                    }];   
}

- (void)testGetAADServiceInfoFromDisambiguationResponse{
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.activeDirectoryAppId = @"foo";
    appconfig.activeDirectoryRedirectURL = @"bar";
   
    NSString *email = @"baz";
    NSURL *resposneURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/?%@=%@&%@=%@",
                                               OD_DISCOVERY_REDIRECT_URL,
                                               OD_AUTH_USER_EMAIL,
                                               email,
                                               OD_DISCOVERY_ACCOUNT_TYPE,
                                               OD_DISCOVERY_ACCOUNT_TYPE_AAD]];
    
    ODServiceInfo *serviceInfo = [self.serviceInfoProvider serviceInfoFromDiscoveryResponse:resposneURL appConfig:appconfig error:nil];
    
    XCTAssertNotNil(serviceInfo);
    XCTAssertEqual(serviceInfo.accountType, ODADAccount);
    XCTAssertEqualObjects(serviceInfo.userEmail, email);
}

- (void)testGetMSAServiceInfoFromDisamabiguationResposne{
    
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.microsoftAccountAppId = @"foo";
    appconfig.microsoftAccountScopes = @[];
   
    NSString *email = @"baz";
    NSURL *resposneURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/?%@=%@&%@=%@",
                                               OD_DISCOVERY_REDIRECT_URL,
                                               OD_AUTH_USER_EMAIL,
                                               email,
                                               OD_DISCOVERY_ACCOUNT_TYPE,
                                               OD_DISCOVERY_ACCOUNT_TYPE_MSA]];
    
    ODServiceInfo *serviceInfo = [self.serviceInfoProvider serviceInfoFromDiscoveryResponse:resposneURL appConfig:appconfig error:nil];
    
    XCTAssertNotNil(serviceInfo);
    XCTAssertEqual(serviceInfo.accountType, ODMSAAccount);
    XCTAssertEqualObjects(serviceInfo.userEmail, email);
}

- (void)testGetInvalidServiceInfoFromDisambiguationResponse{
    ODAppConfiguration *appconfig = [[ODAppConfiguration alloc] init];
    appconfig.microsoftAccountAppId = @"foo";
    appconfig.microsoftAccountScopes = @[];
   
    NSString *email = @"baz";
    NSURL *resposneURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/?%@=%@&%@=%@",
                                               OD_DISCOVERY_REDIRECT_URL,
                                               OD_AUTH_USER_EMAIL,
                                               email,
                                               OD_DISCOVERY_ACCOUNT_TYPE,
                                               OD_DISCOVERY_ACCOUNT_TYPE_AAD]];
    NSError *error = nil;
    ODServiceInfo *serviceInfo = [self.serviceInfoProvider serviceInfoFromDiscoveryResponse:resposneURL
                                                                                  appConfig:appconfig
                                                                                      error:&error];
    
    XCTAssertNil(serviceInfo);
    XCTAssertNotNil(error);
}




@end
