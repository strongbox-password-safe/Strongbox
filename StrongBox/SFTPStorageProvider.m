//
//  SFTPStorageProvider.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SFTPStorageProvider.h"
#import "Utils.h"
#import "NMSSH.h"
#import "NSArray+Extensions.h"
#import "SFTPProviderData.h"
#import "Constants.h"
#import "NSDate+Extensions.h"
#import "SFTPConnections.h"

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"
#import "Alerts.h"

#else

#import "MacAlerts.h"
#import "MacUrlSchemes.h"
#import "ProgressWindow.h"

#endif


@interface SFTPStorageProvider ()

@property NMSFTP* maintainedSessionForListing;
@property SFTPSessionConfiguration* maintainedConfigurationForFastListing;

#if TARGET_OS_IPHONE

#else

@property ProgressWindow* progressWindow;

#endif

@end

@implementation SFTPStorageProvider

+ (instancetype)sharedInstance {
    static SFTPStorageProvider *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SFTPStorageProvider alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        _storageId = kSFTP;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
        _defaultForImmediatelyOfferOfflineCache = NO; 
        _supportsConcurrentRequests = NO; 
    }
    
    return self;
}

- (void)dismissProgressSpinner {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD dismiss];
#else
        [self.progressWindow hide];
#endif
    });
}

- (void)showProgressSpinner:(NSString*)message viewController:(VIEW_CONTROLLER_PTR)viewController {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [SVProgressHUD showWithStatus:message];
#else
        if ( self.progressWindow ) {
            [self.progressWindow hide];
        }
        self.progressWindow = [ProgressWindow newProgress:message];
        [viewController.view.window beginSheet:self.progressWindow.window completionHandler:nil];
#endif
    });
}

- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR )viewController
    completion:(void (^)(METADATA_PTR , const NSError *))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListing) { 
        [self createWithSession:nickName extension:extension data:data
                   parentFolder:parentFolder sftp:self.maintainedSessionForListing
                  configuration:self.maintainedConfigurationForFastListing completion:completion];
    }
    else {
        [self connectAndAuthenticate:nil
                      viewController:viewController
                          completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
            if(userCancelled || sftp == nil || error) {
                completion(nil, error);
                return;
            }
            
            [self createWithSession:nickName extension:extension data:data parentFolder:parentFolder sftp:sftp configuration:configuration completion:completion];
        }];
    }
}

-(void)createWithSession:(NSString *)nickName
               extension:(NSString *)extension
                    data:(NSData *)data
            parentFolder:(NSObject *)parentFolder
                    sftp:(NMSFTP*)sftp
           configuration:(SFTPSessionConfiguration*)configuration
              completion:(void (^)(METADATA_PTR , NSError *))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
    NSString *dir = [self getDirectoryFromParentFolderObject:parentFolder sessionConfig:configuration];
    NSString *path = [NSString pathWithComponents:@[dir, desiredFilename]];

    if(![sftp writeContents:data toFileAtPath:path progress:nil]) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_create", @"Could not create file") errorCode:-3];
        completion(nil, error);
        return;
    }
    
    SFTPProviderData* providerData = makeProviderData(path, configuration);
    METADATA_PTR metadata = [self getSafeMetaData:nickName providerData:providerData];

    [sftp disconnect];

    completion(metadata, nil);
}

- (void)list:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR )viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, const NSError *))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListing) {
        [self listWithSftpSession:self.maintainedSessionForListing
                     parentFolder:parentFolder
                   viewController:viewController
                    configuration:self.maintainedConfigurationForFastListing
                       completion:completion];
    }
    else {
        [self connectAndAuthenticate:nil
                      viewController:viewController
                          completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
            if(userCancelled || sftp == nil || error) {
                completion(userCancelled, nil, error);
                return;
            }
                              
            if(self.maintainSessionForListing) {
                self.maintainedSessionForListing = sftp;
                self.maintainedConfigurationForFastListing = configuration;
            }
                              
            [self listWithSftpSession:sftp parentFolder:parentFolder viewController:viewController configuration:configuration completion:completion];
                              
            if(!self.maintainSessionForListing) {
                [sftp disconnect];
            }
        }];
    }
}

- (void)listWithSftpSession:(NMSFTP*)sftp
               parentFolder:(NSObject *)parentFolder
             viewController:(VIEW_CONTROLLER_PTR )viewController
              configuration:(SFTPSessionConfiguration *)configuration
                 completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_listing", @"Listing...") viewController:viewController];
    
    NSString * dir = [self getDirectoryFromParentFolderObject:parentFolder sessionConfig:configuration];
    
    NSArray<NMSFTPFile*>* files = [sftp contentsOfDirectoryAtPath:dir];
    
    [self dismissProgressSpinner];
    
    if (files == nil) {
        completion(NO, nil, sftp.session.lastError); 
    }
    else {
        NSArray<StorageBrowserItem*>* browserItems = [files map:^id _Nonnull(NMSFTPFile * _Nonnull obj, NSUInteger idx) {
            NSString* name = obj.isDirectory && obj.filename.length > 1 ? [obj.filename substringToIndex:obj.filename.length-1] : obj.filename;
            BOOL folder = obj.isDirectory;
            NSString* path = [NSString pathWithComponents:@[dir, name]];
            id providerData = makeProviderData(path, configuration);
            
            return [StorageBrowserItem itemWithName:name identifier:path folder:folder providerData:providerData];
        }];
        
        completion(NO, browserItems, nil);
    }
}

- (void)pushDatabase:(METADATA_PTR )safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR )viewController
                data:(NSData *)data
          completion:(StorageProviderUpdateCompletionBlock)completion {
    SFTPProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    SFTPSessionConfiguration* connection = [self getConnectionFromProviderData:providerData];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completion(kUpdateResultError, nil, error );
        return;
    }
    
    [self connectAndAuthenticate:connection
                  viewController:nil
                      completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if(sftp == nil || error) {
            completion(kUpdateResultError, nil, error);
            return;
        }
    
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:viewController];
        }

        if(![sftp writeContents:data toFileAtPath:providerData.filePath progress:nil]) {
            if (viewController) {
                [self dismissProgressSpinner];
            }

            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_update", @"Could not update file") errorCode:-3];
            completion(kUpdateResultError, nil, error);
        }
        else {
            NMSFTPFile* attr = [sftp infoForFileAtPath:providerData.filePath];
            if(!attr) {
                error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
                completion(kUpdateResultError, nil, error);
            }

            if (viewController) {
                [self dismissProgressSpinner];
            }
            
            completion(kUpdateResultSuccess, attr.modificationDate, nil);
        }
        
        [sftp disconnect];
    }];
}



- (void)delete:(METADATA_PTR )safeMetaData completion:(void (^)(const NSError *))completion {
    
}

- (void)loadIcon:(NSObject *)providerData viewController:(VIEW_CONTROLLER_PTR )viewController completion:(void (^)(IMAGE_TYPE_PTR))completionHandler {
    
}



- (SFTPProviderData*)getProviderDataFromMetaData:(METADATA_PTR )metaData {
#if TARGET_OS_IPHONE
    NSString* json = metaData.fileIdentifier;
#else
    NSString* json = metaData.storageInfo;
#endif

    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]  options:kNilOptions error:&error];
    
    SFTPProviderData* foo = [SFTPProviderData fromSerializationDictionary:dictionary];
    
    return foo;
}

- (METADATA_PTR )getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    SFTPProviderData* foo = (SFTPProviderData*)providerData;
    
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
                                         fileName:[foo.filePath lastPathComponent]
                                   fileIdentifier:json];
#else
    NSURLComponents* components = [[NSURLComponents alloc] init];
    components.scheme = kStrongboxSFTPUrlScheme;
    components.host = foo.sFtpConfiguration.host;
    components.path = foo.filePath;
    
    
    
    DatabaseMetadata *ret = [[DatabaseMetadata alloc] initWithNickName:nickName
                                                       storageProvider:self.storageId
                                                               fileUrl:components.URL
                                                           storageInfo:json];
    
    
    
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"uuid" value:ret.uuid]];
    
    ret.fileUrl = components.URL;
    
    return ret;
#endif
}

- (void)pullDatabase:(METADATA_PTR)safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR )viewController
             options:(StorageProviderReadOptions     *)options
          completion:(StorageProviderReadCompletionBlock)completion {
    SFTPProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self readWithProviderData:providerData viewController:viewController options:options completion:completion];
}

- (void)getModDate:(METADATA_PTR)safeMetaData completion:(StorageProviderGetModDateCompletionBlock)completion {
    SFTPProviderData* foo = [self getProviderDataFromMetaData:safeMetaData];
    SFTPSessionConfiguration* connection = [self getConnectionFromProviderData:foo];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completion(nil, error );
        return;
    }




    [self connectAndAuthenticate:connection
                  viewController:nil
                      completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if(sftp == nil || error) {
            completion(nil, error);
            return;
        }
                
        NMSFTPFile* attr = [sftp infoForFileAtPath:foo.filePath];
        if(!attr) {
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            completion(nil, error);
            return;
        }
        
        completion(attr.modificationDate, nil);
    }];
}

- (void)readWithProviderData:(NSObject *)providerData
              viewController:(VIEW_CONTROLLER_PTR )viewController
                     options:(StorageProviderReadOptions *)options
                  completion:(StorageProviderReadCompletionBlock)completionHandler {
    SFTPProviderData* foo = (SFTPProviderData*)providerData;
    SFTPSessionConfiguration* connection = [self getConnectionFromProviderData:foo];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completionHandler(kReadResultError, nil, nil, error );
        return;
    }

    [self connectAndAuthenticate:connection
                  viewController:viewController
                      completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if(sftp == nil || error) {
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_reading", @"A storage provider is in the process of reading. This is the status displayed on the progress dialog. In english:  Reading...")
                       viewController:viewController];
        }
        
        NMSFTPFile* attr = [sftp infoForFileAtPath:foo.filePath];
        if(!attr) {
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        if (options.onlyIfModifiedDifferentFrom && [options.onlyIfModifiedDifferentFrom isEqualToDateWithinEpsilon:attr.modificationDate]) {
            if (viewController) {
                [self dismissProgressSpinner];
            }

            completionHandler(kReadResultModifiedIsSameAsLocal, nil, nil, error);
            return;
        }

        NSData* data = [sftp contentsAtPath:foo.filePath];
        
        if (viewController) {
            [self dismissProgressSpinner];
        }
     
        if(!data) {
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        [sftp disconnect];
        
        completionHandler(kReadResultSuccess, data, attr.modificationDate, nil);
    }];
}

- (NSString *)getDirectoryFromParentFolderObject:(NSObject *)parentFolder sessionConfig:(SFTPSessionConfiguration*)sessionConfig {
    SFTPProviderData* parent = (SFTPProviderData*)parentFolder;

    NSString* dir = parent ? parent.filePath : (sessionConfig != nil && sessionConfig.initialDirectory.length ? sessionConfig.initialDirectory : @"/");

    return dir;
}

- (void)connectAndAuthenticate:(SFTPSessionConfiguration*)sessionConfiguration
                viewController:(VIEW_CONTROLLER_PTR)viewController
                    completion:(void (^)(BOOL userCancelled, NMSFTP* sftp, SFTPSessionConfiguration* configuration, NSError* error))completion {
    
    
    

    sessionConfiguration = sessionConfiguration ? sessionConfiguration : self.explicitConnection;
    
    NSError* error;
    NMSFTP* sftp = [self connectAndAuthenticateWithSessionConfiguration:sessionConfiguration viewController:viewController error:&error];
    

    
    completion(NO, sftp, sessionConfiguration, error);
}

- (NMSFTP*)connectAndAuthenticateWithSessionConfiguration:(SFTPSessionConfiguration*)sessionConfiguration
                                           viewController:viewController
                                                    error:(NSError**)error {
    NSLog(@"Connecting to %@", sessionConfiguration.host);
    
    if ( ( sessionConfiguration.authenticationMode == kPrivateKey && sessionConfiguration.privateKey == nil ) || ( sessionConfiguration.authenticationMode == kUsernamePassword && sessionConfiguration.password == nil ) ) {
        if ( error ) {
            NSString* loc = NSLocalizedString(@"password_unavailable_please_edit_connection_error", @"Your private key or password is no longer available, probably because you've just migrated to a new device.\nPlease edit your connection to fix.");
            
            *error = [Utils createNSError:loc errorCode:kStorageProviderSFTPorWebDAVSecretMissingErrorCode];
        }
        return nil;
    }
    
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_connecting", @"Connecting...")
                   viewController:viewController];
    }
    
    
    
    
    
    
    
    
    
    
    
    
    

    NMSSHSession *session = nil;
    @try {
        session = [NMSSHSession connectToHost:sessionConfiguration.host withUsername:sessionConfiguration.username];
    } @catch (NSException *exception) {
        NSLog(@"WARNWARN: SSH Connect Exception: %@", exception);
        if ( error ) {
            *error = [Utils createNSError:exception.reason errorCode:-1234];
        }
        return nil;
    }
    
    if (viewController) {
        [self dismissProgressSpinner];
    }
    
    if (session.isConnected) {
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating", @"Authenticating...")
                       viewController:viewController];
        }
        
        NSLog(@"Supported Authentication Methods by Server: [%@]", session.supportedAuthenticationMethods);
        
        if(sessionConfiguration.authenticationMode == kPrivateKey) {
            [session authenticateByInMemoryPublicKey:sessionConfiguration.publicKey
                                          privateKey:sessionConfiguration.privateKey
                                         andPassword:sessionConfiguration.password];
        }
        else {
            [session authenticateByPassword:sessionConfiguration.password];
        }

        if (viewController) {
            [self dismissProgressSpinner];
        }

        if (!session.isAuthorized) {
            if(error) {
                *error = [Utils createNSError:[NSString stringWithFormat:NSLocalizedString(@"sftp_provider_auth_failed_fmt", @"Authentication Failed for [user: %@]"), sessionConfiguration.username] errorCode:-2];
            }
            return nil;
        }
    }
    else {
        if(error) {
            *error = [Utils createNSError:[NSString stringWithFormat:NSLocalizedString(@"sftp_provider_connect_failed_fmt", @"Could not connect to host: %@ [user: %@]"),
                                           sessionConfiguration.host, sessionConfiguration.username] errorCode:-1];
        }
        return nil;
    }
    
    NMSFTP *sftp = [NMSFTP connectWithSession:session];
    
    return sftp;
}

static SFTPProviderData* makeProviderData(NSString* path, SFTPSessionConfiguration* sftpConfiguration) {
    SFTPProviderData *providerData = [[SFTPProviderData alloc] init];
    
    providerData.filePath = path;
    providerData.connectionIdentifier = sftpConfiguration.identifier;

    
    
    return providerData;
}

- (void)testConnection:(SFTPSessionConfiguration *)connection
        viewController:(VIEW_CONTROLLER_PTR)viewController
            completion:(void (^)(NSError * _Nonnull))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSError* error;
        
        [self connectAndAuthenticateWithSessionConfiguration:connection viewController:viewController error:&error];
        
        completion(error);
    });
}

- (SFTPSessionConfiguration*)getConnectionFromProviderData:(SFTPProviderData*)provider {
    return [SFTPConnections.sharedInstance getById:provider.connectionIdentifier];
}

- (SFTPSessionConfiguration *)getConnectionFromDatabase:(METADATA_PTR)metaData {
    return [self getConnectionFromProviderData:[self getProviderDataFromMetaData:metaData]];
}

@end

