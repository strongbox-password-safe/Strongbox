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
#import "WebDAVConnections.h"

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"

#else

#import "MacUrlSchemes.h"
#import "macOSSpinnerUI.h"

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

- (void)dismissProgressSpinner {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD dismiss];
#else
        [macOSSpinnerUI.sharedInstance dismiss];
#endif
    });
}

- (void)showProgressSpinner:(NSString*)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD showWithStatus:message];
#else
        [macOSSpinnerUI.sharedInstance show:message viewController:viewController];
#endif
    });
}

-(void)connect:(WebDAVSessionConfiguration*)config
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(BOOL userCancelled, DAVSession* session, WebDAVSessionConfiguration* configuration, NSError* error))completion {
    config = config ? config : self.explicitConnection;
    
    if ( config.password == nil ) {
        NSString* loc = NSLocalizedString(@"password_unavailable_please_edit_connection_error", @"Your private key or password is no longer available, probably because you've just migrated to a new device.\nPlease edit your connection to fix.");
        NSError *error = [Utils createNSError:loc errorCode:kStorageProviderSFTPorWebDAVSecretMissingErrorCode];
        completion ( NO, nil, config, error);
        return;
    }

    DAVCredentials *credentials = [DAVCredentials credentialsWithUsername:config.username password:config.password];
    DAVSession *session = [[DAVSession alloc] initWithRootURL:config.host credentials:credentials];
    session.allowUntrustedCertificate = config.allowUntrustedCertificate;
    
    completion(NO, session, config, nil);
}



- (void)create:(NSString *)nickName 
      fileName:(NSString *)fileName
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListings) { 
        [self createWithSession:nickName
                       fileName:fileName
                           data:data
                   parentFolder:parentFolder
                        session:self.maintainedSessionForListings
                  configuration:self.maintainedConfigurationForListings
                 viewController:viewController
                     completion:completion];
    }
    else {
        [self connect:nil viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
            if(userCancelled || !session || error) {
                NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
                completion(nil, error);
                return;
            }
            
            [self createWithSession:nickName
                           fileName:fileName
                               data:data
                       parentFolder:parentFolder
                            session:session
                      configuration:configuration
                     viewController:viewController
                         completion:completion];
        }];
    }
}

- (void)createWithSession:(NSString *)nickName
                 fileName:(NSString *)fileName
                     data:(NSData *)data
             parentFolder:(NSObject *)parentFolder
                  session:(DAVSession*)session
            configuration:(WebDAVSessionConfiguration*)configuration
           viewController:(VIEW_CONTROLLER_PTR)viewController
               completion:(void (^)(METADATA_PTR, NSError *))completion {
    WebDAVProviderData* providerData = (WebDAVProviderData*)parentFolder;
    
    NSString* path;
    NSString* root = providerData ? (providerData.href.length ? providerData.href : @"/") : @"/";
    NSURL* ur = root.urlExtendedParse;
    
    if (ur == nil || ur.scheme == nil) {
        path = [root stringByAppendingPathComponent:fileName];
    }
    else {
        
        
        

        path = [ur URLByAppendingPathComponent:fileName].absoluteString; 
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
            METADATA_PTR metadata = [self getDatabasePreferences:nickName providerData:providerData];
            completion(metadata, nil);
        }
    };

    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_creating", @"Creating...") viewController:viewController];
    
    [session enqueueRequest:request];
}







- (void)list:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListings) {
        [self listWithSession:self.maintainedSessionForListings
                 parentFolder:parentFolder
                configuration:self.maintainedConfigurationForListings
               viewController:viewController
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
        
            if(self.maintainSessionForListing) {
                self.maintainedSessionForListings = session;
                self.maintainedConfigurationForListings = configuration;
            }
            
            [self listWithSession:session parentFolder:parentFolder configuration:configuration viewController:viewController completion:completion];
        }];
    }
}

- (void)listWithSession:(DAVSession*)session
           parentFolder:(NSObject*)parentFolder
          configuration:(WebDAVSessionConfiguration*)configuration
         viewController:(VIEW_CONTROLLER_PTR)viewController
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

    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_listing", @"Listing...") viewController:viewController];

    [session enqueueRequest:listingRequest];
}

- (void)pullDatabase:(METADATA_PTR)safeMetaData interactiveVC:(VIEW_CONTROLLER_PTR)viewController options:(StorageProviderReadOptions *)options completion:(StorageProviderReadCompletionBlock)completion {
    WebDAVProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self readWithProviderData:providerData viewController:viewController options:options completion:completion];
}

- (void)getModDate:(METADATA_PTR)safeMetaData completion:(StorageProviderGetModDateCompletionBlock)completion {
    WebDAVProviderData* pd = [self getProviderDataFromMetaData:safeMetaData];
    WebDAVSessionConfiguration* connection = [self getConnectionFromProviderData:pd];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completion(YES, nil, error);
        return;
    }
    
    [self connect:connection viewController:nil
       completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
        if(!session) {
            NSError* error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
            completion(YES, nil, error);
            return;
        }
        
        
        
                    
        
        
        NSString* path = pd.href.stringByDeletingLastPathComponent; 
        
        DAVListingRequest* listingRequest = [[DAVListingRequest alloc] initWithPath:path];
        listingRequest.delegate = self;
        
        listingRequest.strongboxCompletion = ^(BOOL success, id result, NSError *error) {
            if(!success) {
                completion(YES, nil, error);
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
                    NSError* error = [Utils createNSError:@"Could not get attributes of webdav file" errorCode:-2];
                    completion(YES, nil, error);
                    return;
                }
                
                NSDate* modDate = responseItem.modificationDate;
                completion(YES, modDate, nil);
            }
        };
        
        [session enqueueRequest:listingRequest];
    }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(VIEW_CONTROLLER_PTR)viewController
                     options:(StorageProviderReadOptions *)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler {
    WebDAVProviderData* pd = (WebDAVProviderData*)providerData;
    WebDAVSessionConfiguration* connection = [self getConnectionFromProviderData:pd];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completionHandler(kReadResultError, nil, nil, error);
        return;
    }
    
    if (!viewController && [self userInteractionRequiredForConnection:connection]) {
        completionHandler(kReadResultError, nil, nil, kUserInteractionRequiredError);
        return;
    }

    [self connect:connection viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
        if(!session) {
            if ( error == nil ) {
                error = [Utils createNSError:NSLocalizedString(@"webdav_storage_could_not_connect", @"Could not connect to server.") errorCode:-2];
            }
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
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...") viewController:viewController];
        }
        
        [session enqueueRequest:listingRequest];
    }];
}

- (void)pushDatabase:(METADATA_PTR)safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR)viewController
                data:(NSData *)data
          completion:(StorageProviderUpdateCompletionBlock)completion {
    WebDAVProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    WebDAVSessionConfiguration* connection = [self getConnectionFromProviderData:providerData];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completion(kUpdateResultError, nil, error);
        return;
    }
    
    [self connect:connection viewController:viewController completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
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
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:viewController];
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
    ret.connectionIdentifier = sessionConfiguration.identifier;
    

    
    return ret;
}

- (WebDAVProviderData*)getProviderDataFromMetaData:(METADATA_PTR)metaData {

#if TARGET_OS_IPHONE
    NSString* json = metaData.fileIdentifier;
#else
    NSString* json = metaData.storageInfo;
#endif
    
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:kNilOptions
                                                                 error:&error];
    
    WebDAVProviderData* foo = [WebDAVProviderData fromSerializationDictionary:dictionary];
    
    return foo;
}

- (METADATA_PTR)getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    WebDAVProviderData* foo = (WebDAVProviderData*)providerData;
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:[foo serializationDictionary] options:0 error:&error];
    
    if(error) {
        slog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
#if TARGET_OS_IPHONE
    DatabasePreferences *ret = [DatabasePreferences templateDummyWithNickName:nickName
                                                              storageProvider:self.storageId
                                                                     fileName:[[foo.href lastPathComponent] stringByRemovingPercentEncoding]
                                                               fileIdentifier:json];
    
    ret.lazySyncMode = YES; 
#else
    NSURLComponents* components = [NSURLComponents componentsWithString:foo.href];
    
    
    NSURLComponents* newComponents = [NSURLComponents new];
    newComponents.scheme = kStrongboxWebDAVUrlScheme;
    newComponents.host = components.host;
    newComponents.path = components.path;
    
    
    
    MacDatabasePreferences *ret = [MacDatabasePreferences templateDummyWithNickName:nickName
                                                                    storageProvider:self.storageId
                                                                            fileUrl:newComponents.URL
                                                                        storageInfo:json];
    
    
    
    newComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"uuid" value:ret.uuid]];
    
    ret.fileUrl = newComponents.URL;
#endif
    
    return ret;
}



- (void)delete:(METADATA_PTR)safeMetaData completion:(void (^)(const NSError *))completion {
    
}

- (void)loadIcon:(NSObject *)providerData viewController:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(IMAGE_TYPE_PTR))completionHandler {
    
}
    
- (void)testConnection:(WebDAVSessionConfiguration*)connection viewController:(VIEW_CONTROLLER_PTR)viewController completion:(void (^)(NSError* error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        [self connect:connection
       viewController:viewController
           completion:^(BOOL userCancelled, DAVSession *session, WebDAVSessionConfiguration *configuration, NSError *error) {
            [self listWithSession:session parentFolder:nil configuration:configuration viewController:viewController completion:^(BOOL foo, NSArray<StorageBrowserItem *> *items, NSError *error) {
                completion(error);
            }];
        }];
    });
}

- (WebDAVSessionConfiguration*)getConnectionFromProviderData:(WebDAVProviderData*)provider {
    return [WebDAVConnections.sharedInstance getById:provider.connectionIdentifier];
}

- (WebDAVSessionConfiguration *)getConnectionFromDatabase:(METADATA_PTR)metaData {
    WebDAVProviderData* pd = [self getProviderDataFromMetaData:metaData];
    return [self getConnectionFromProviderData:pd];
}

@end
