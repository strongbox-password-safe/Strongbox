//
//  WebDAVStorageProvider.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "WebDAVStorageProvider.h"
#import "WebDAVSessionConfiguration.h"
#import "NSArray+Extensions.h"
#import "WebDAVProviderData.h"
#import "Utils.h"
#import "Constants.h"
#import "NSString+Extensions.h"
#import "NSDate+Extensions.h"

#if TARGET_OS_IPHONE

#import "WebDAVConfigurationViewController.h"
#import "SVProgressHUD.h"

#else

#endif


@interface WebDAVStorageProvider ()

@property DAVSession* maintainedSessionForListings;
@property WebDAVSessionConfiguration* maintainedConfigurationForListings;

@end

@implementation WebDAVStorageProvider

+ (instancetype)sharedInstance {
    static WebDAVStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WebDAVStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        _storageId = kWebDAV;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = NO; 
        _supportsConcurrentRequests = NO; 
    }
    
    return self;
}

- (void)request:(DAVRequest *)aRequest didFailWithError:(NSError *)error {
    if(aRequest.strongboxCompletion) {
        aRequest.strongboxCompletion(NO, nil, error);
    }
}

- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result {
    if(aRequest.strongboxCompletion) {
        aRequest.strongboxCompletion(YES, result, nil);
    }
}

- (BOOL)userInteractionRequiredForConnection:(WebDAVSessionConfiguration*)config {
    return config == nil;
}




- (void)presentConfigurationDialog:(VIEW_CONTROLLER_PTR)viewController
                        completion:(void (^)(BOOL userCancelled, DAVSession* session, WebDAVSessionConfiguration* configuration, NSError* error))completion {
#if TARGET_OS_IPHONE
    WebDAVConfigurationViewController *vc = [[WebDAVConfigurationViewController alloc] init];
    __weak WebDAVConfigurationViewController* weakRef = vc;
    vc.onDone = ^(BOOL success) {
        [viewController dismissViewControllerAnimated:YES completion:^{
            if(success) {
                DAVCredentials *credentials = [DAVCredentials credentialsWithUsername:weakRef.configuration.username password:weakRef.configuration.password];
                DAVSession *session = [[DAVSession alloc] initWithRootURL:weakRef.configuration.host credentials:credentials];
                session.allowUntrustedCertificate = weakRef.configuration.allowUntrustedCertificate;
                
                completion(NO, session, weakRef.configuration, nil);
            }
            else {
                completion(YES, nil, nil, nil);
            }
        }];
    };

    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [viewController presentViewController:vc animated:YES completion:nil];
#endif
}

- (void)dismissProgressSpinner {
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
    });
#else
    
#endif
}

- (void)showProgressSpinner:(NSString*)message {
#if TARGET_OS_IPHONE
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:message];
    });
#else
    
#endif
}




-(void)connect:(WebDAVSessionConfiguration*)config
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(BOOL userCancelled, DAVSession* session, WebDAVSessionConfiguration* configuration, NSError* error))completion {
    if(config == nil) {
        if(self.unitTestSessionConfiguration != nil) { 
            config = self.unitTestSessionConfiguration;
        }
        else {
            [self presentConfigurationDialog:viewController completion:completion];
            return;
        }
    }
    
    DAVCredentials *credentials = [DAVCredentials credentialsWithUsername:config.username password:config.password];
    DAVSession *session = [[DAVSession alloc] initWithRootURL:config.host credentials:credentials];
    session.allowUntrustedCertificate = config.allowUntrustedCertificate;
    
    completion(NO, session, config, nil);
}



- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR, const NSError *))completion {
    if(self.maintainSessionForListings && self.maintainedSessionForListings) { 
        [self createWithSession:nickName extension:extension data:data
                   parentFolder:parentFolder session:self.maintainedSessionForListings
                  configuration:self.maintainedConfigurationForListings completion:completion];
    }
    else {
        [self connect:nil viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
            if(userCancelled || !session || error) {
                NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
                completion(nil, error);
                return;
            }
            
            [self createWithSession:nickName extension:extension data:data
                       parentFolder:parentFolder session:session
                      configuration:configuration completion:completion];
        }];
    }
}

- (void)createWithSession:(NSString *)nickName
                extension:(NSString *)extension
                     data:(NSData *)data
             parentFolder:(NSObject *)parentFolder
                  session:(DAVSession*)session
            configuration:(WebDAVSessionConfiguration*)configuration
               completion:(void (^)(METADATA_PTR, NSError *))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
    
    WebDAVProviderData* providerData = (WebDAVProviderData*)parentFolder;
    
    NSString* path;
    NSString* root = providerData ? (providerData.href.length ? providerData.href : @"/") : @"/";
    NSURL* ur = root.urlExtendedParse;
    
    if (ur == nil || ur.scheme == nil) {
        path = [root stringByAppendingPathComponent:desiredFilename];
    }
    else {
        
        
        

        path = [ur URLByAppendingPathComponent:desiredFilename].absoluteString; 
    }
        
    DAVPutRequest *request = [[DAVPutRequest alloc] initWithPath:path];
    request.data = data;
    request.delegate = self;
    request.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
        [self dismissProgressSpinner];
        
        if(!success) {
            completion(nil, error);
        }
        else {
            WebDAVProviderData* providerData = makeProviderData(path, configuration);
            METADATA_PTR metadata = [self getSafeMetaData:nickName providerData:providerData];
            completion(metadata, nil);
        }
    };

    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_creating", @"Creating...")];
    
    [session enqueueRequest:request];
}







- (void)list:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    if(self.maintainSessionForListings && self.maintainedSessionForListings) {
        [self listWithSession:self.maintainedSessionForListings
                    parentFolder:parentFolder
                    configuration:self.maintainedConfigurationForListings
                       completion:completion];
    }
    else {
        [self connect:nil viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
            if(userCancelled) {
                completion(YES, nil, nil);
                return;
            }
        
            if(!session || error) {
                NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
                completion(NO, nil, error);
                return;
            }
        
            if(self.maintainSessionForListings) {
                self.maintainedSessionForListings = session;
                self.maintainedConfigurationForListings = configuration;
            }
            
            [self listWithSession:session parentFolder:parentFolder configuration:configuration completion:completion];
        }];
    }
}

- (void)listWithSession:(DAVSession*)session
           parentFolder:(NSObject*)parentFolder
          configuration:(WebDAVSessionConfiguration*)configuration
             completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    WebDAVProviderData* providerData = (WebDAVProviderData*)parentFolder;
    NSString* path = providerData ? (providerData.href.length ? providerData.href : @"/") : @"/";
    DAVListingRequest* listingRequest = [[DAVListingRequest alloc] initWithPath:path];

    listingRequest.delegate = self;
    listingRequest.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
        [self dismissProgressSpinner];

        if(error) {
            completion(NO, nil, error);
            return;
        }
        else {
            NSArray<DAVResponseItem*>* files = result;
            

            NSURL *parentUrl = [NSURL URLWithString:path];
            if([parentUrl scheme] == nil) {
                parentUrl = [configuration.host URLByAppendingPathComponent:path];
            }

            files = [files filter:^BOOL(DAVResponseItem * _Nonnull obj) {
                return obj.href && [parentUrl.absoluteString compare:obj.href.absoluteString] != NSOrderedSame;
            }];
            
            NSArray<StorageBrowserItem*>* browserItems = [files map:^id _Nonnull(DAVResponseItem * _Nonnull obj, NSUInteger idx) {
                NSString* name = [obj.href lastPathComponent];
                BOOL folder = obj.resourceType == DAVResourceTypeCollection;
                id providerData = makeProviderData(obj.href.absoluteString, configuration);
            
                return [StorageBrowserItem itemWithName:name identifier:path folder:folder providerData:providerData]; 
            }];
            
            
            completion(NO, browserItems, nil);
        }
    };

    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_listing", @"Listing...")]; 

    [session enqueueRequest:listingRequest];
}

- (void)pullDatabase:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    WebDAVProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self readWithProviderData:providerData viewController:viewController options:options completion:completion];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(VIEW_CONTROLLER_PTR)viewController
                     options:(StorageProviderReadOptions *)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler {
    WebDAVProviderData* pd = (WebDAVProviderData*)providerData;
    if (!viewController && [self userInteractionRequiredForConnection:pd.sessionConfiguration]) {
        completionHandler(kReadResultError, nil, nil, kUserInteractionRequiredError);
        return;
    }

    [self connect:pd.sessionConfiguration viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
        if(!session) {
            NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        
        
                    
        
        
        NSString* path = pd.href.stringByDeletingLastPathComponent; 
        
        DAVListingRequest* listingRequest = [[DAVListingRequest alloc] initWithPath:path];
        listingRequest.delegate = self;
        listingRequest.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
            if(!success) {
                if (viewController) {
                    [self dismissProgressSpinner];
                }
                
                completionHandler(kReadResultError, nil, nil, error);
            }
            else {
                NSArray<DAVResponseItem*>* listingResponse = (NSArray<DAVResponseItem*>*)result;
                NSString* targetFileName = pd.href.lastPathComponent;       
                NSString* urlDecodedTargetFileName = [targetFileName stringByRemovingPercentEncoding];
                            
                DAVResponseItem* responseItem = [listingResponse firstOrDefault:^BOOL(DAVResponseItem * _Nonnull obj) {
                    NSString* foo = obj.href.path.lastPathComponent;
                    
                    return [foo isEqualToString:targetFileName] || [foo isEqualToString:urlDecodedTargetFileName];
                }];

                if (!responseItem) {
                    if (viewController) {
                        [self dismissProgressSpinner];
                    }

                    NSError* error = [Utils createNSError:@"Could not get attributes of webdav file" errorCode:-2];
                    completionHandler(kReadResultError, nil, nil, error);
                    return;
                }
                
                NSDate* modDate = responseItem.modificationDate;
                
                if (modDate && options && options.onlyIfModifiedDifferentFrom && [options.onlyIfModifiedDifferentFrom isEqualToDateWithinEpsilon:modDate]) {
                    if (viewController) {
                        [self dismissProgressSpinner];
                    }

                    completionHandler(kReadResultModifiedIsSameAsLocal, nil, nil, error);
                    return;
                }
                
                DAVGetRequest *request = [[DAVGetRequest alloc] initWithPath:pd.href];
                request.delegate = self;
                request.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
                    if (viewController) {
                        [self dismissProgressSpinner];
                    }
                    
                    if(!success) {
                        completionHandler(kReadResultError, nil, nil, error);
                    }
                    else {
                        completionHandler(kReadResultSuccess, result, modDate, nil);
                    }
                };

                [session enqueueRequest:request];
            }
        };
  
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")];
        }
        
        [session enqueueRequest:listingRequest];
    }];
}

- (void)pushDatabase:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController data:(NSData *)data completion:(StorageProviderUpdateCompletionBlock)completion {
    WebDAVProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    
    [self connect:providerData.sessionConfiguration viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
        if(!session) {
            NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
            completion(kUpdateResultError, nil, error);
            return;
        }
        
        DAVPutRequest *request = [[DAVPutRequest alloc] initWithPath:providerData.href];
        request.data = data;
        request.delegate = self;
        request.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
            if (!success) {
                if (viewController) {
                    [self dismissProgressSpinner];
                 }

                completion(kUpdateResultError, nil, error);
                return;
            }
            else {
                [self onPutDone:safeMetaData interactiveVC:viewController session:session completion:completion];
            }
        };
        
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
        }
        
        [session enqueueRequest:request];
    }];
}

- (void)onPutDone:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController session:(DAVSession*)session completion:(StorageProviderUpdateCompletionBlock)completion {
    WebDAVProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    
    NSString* path = providerData.href.stringByDeletingLastPathComponent; 
    DAVListingRequest* listingRequest = [[DAVListingRequest alloc] initWithPath:path];
    listingRequest.delegate = self;
    listingRequest.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
        if(!success) {
            if (viewController) {
                [self dismissProgressSpinner];
            }
            
            completion(kUpdateResultError, nil, error);
        }
        else {
            NSArray<DAVResponseItem*>* listingResponse = (NSArray<DAVResponseItem*>*)result;
            NSString* targetFileName = providerData.href.lastPathComponent;       
            NSString* urlDecodedTargetFileName = [targetFileName stringByRemovingPercentEncoding];
                        
            DAVResponseItem* responseItem = [listingResponse firstOrDefault:^BOOL(DAVResponseItem * _Nonnull obj) {
                NSString* foo = obj.href.path.lastPathComponent;
                
                return [foo isEqualToString:targetFileName] || [foo isEqualToString:urlDecodedTargetFileName];
            }];

            if (!responseItem) {
                if (viewController) {
                    [self dismissProgressSpinner];
                }

                NSError* error = [Utils createNSError:@"Could not get attributes of webdav file" errorCode:-2];
                completion(kUpdateResultError, nil, error);
                return;
            }
            
            NSDate* modDate = responseItem.modificationDate;

            if (viewController) {
                [self dismissProgressSpinner];
            }

            completion(kUpdateResultSuccess, modDate, nil);
        }
    };
    
    [session enqueueRequest:listingRequest];
}



static WebDAVProviderData* makeProviderData(NSString *href, WebDAVSessionConfiguration* sessionConfiguration) {
    WebDAVProviderData* ret = [[WebDAVProviderData alloc] init];
    
    ret.href = href;
    ret.sessionConfiguration = sessionConfiguration;
    
    return ret;
}

- (WebDAVProviderData*)getProviderDataFromMetaData:(METADATA_PTR)metaData {

#if TARGET_OS_IPHONE
    NSString* json = metaData.fileIdentifier;
#else
    NSString* json = @"TODO"; 
#endif
    
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:kNilOptions
                                                                 error:&error];
    
    WebDAVProviderData* foo = [WebDAVProviderData fromSerializationDictionary:dictionary];
    
    return foo;
}

- (METADATA_PTR)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    WebDAVProviderData* foo = (WebDAVProviderData*)providerData;
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:[foo serializationDictionary] options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
#if TARGET_OS_IPHONE
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:[[foo.href lastPathComponent] stringByRemovingPercentEncoding]
                                   fileIdentifier:json];
#else
    return nil; 
#endif
}



- (void)delete:(METADATA_PTR)safeMetaData completion:(void (^)(const NSError *))completion {
    
}

- (void)loadIcon:(NSObject *)providerData viewController:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(IMAGE_TYPE_PTR))completionHandler {
    
}
    
@end
