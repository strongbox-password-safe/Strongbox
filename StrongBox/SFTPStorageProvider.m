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
#import "CrossPlatform.h"

#if TARGET_OS_IPHONE

#import "SVProgressHUD.h"
#import "Alerts.h"

#else

#import "MacAlerts.h"
#import "MacUrlSchemes.h"
#import "macOSSpinnerUI.h"

#endif


@interface SFTPStorageProvider () <NMSSHSessionDelegate>

@property NMSFTP* maintainedSessionForListing;
@property SFTPSessionConfiguration* maintainedConfigurationForFastListing;

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

- (void)yesNoAlert:(NSString*)title
           message:(NSString*)message
    viewController:(VIEW_CONTROLLER_PTR)viewController
        completion:(void (^)(BOOL yesNo))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
        [Alerts yesNo:viewController title:title message:message action:completion];
#else
        [MacAlerts yesNo:message window:viewController.view.window completion:completion];
#endif
    });

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

- (void)create:(NSString *)nickName
      fileName:(NSString *)fileName
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(VIEW_CONTROLLER_PTR)viewController
    completion:(void (^)(METADATA_PTR _Nullable, const NSError * _Nullable))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListing) { 
        [self createWithSession:nickName 
                       fileName:fileName
                           data:data
                   parentFolder:parentFolder 
                           sftp:self.maintainedSessionForListing
                  configuration:self.maintainedConfigurationForFastListing 
                     completion:completion];
    }
    else {
        [self connectAndAuthenticate:nil
                      viewController:viewController
                          completion:^( BOOL userInteractionRequired, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
            if ( sftp == nil || error ) {
                completion(nil, error);
                return;
            }
            
            [self createWithSession:nickName 
                           fileName:fileName
                               data:data
                       parentFolder:parentFolder
                               sftp:sftp
                      configuration:configuration
                         completion:completion];
        }];
    }
}

-(void)createWithSession:(NSString *)nickName
                fileName:(NSString *)fileName
                    data:(NSData *)data
            parentFolder:(NSObject *)parentFolder
                    sftp:(NMSFTP*)sftp
           configuration:(SFTPSessionConfiguration*)configuration
              completion:(void (^)(METADATA_PTR , NSError *))completion {
    NSString *dir = [self getDirectoryFromParentFolderObject:parentFolder sessionConfig:configuration];
    NSString *path = [NSString pathWithComponents:@[dir, fileName]];
    
    if(![sftp writeContents:data toFileAtPath:path progress:nil]) {
        NSError* error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_create", @"Could not create file") errorCode:-3];
        completion(nil, error);
        return;
    }
    
    SFTPProviderData* providerData = makeProviderData(path, configuration);
    METADATA_PTR metadata = [self getDatabasePreferences:nickName providerData:providerData];
    
    [sftp.session disconnect];
    
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
                          completion:^(BOOL userInteractionRequired, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
            if ( sftp == nil || error ) {
                completion(NO, nil, error);
                return;
            }
            
            if(self.maintainSessionForListing) {
                self.maintainedSessionForListing = sftp;
                self.maintainedConfigurationForFastListing = configuration;
            }
            
            [self listWithSftpSession:sftp parentFolder:parentFolder viewController:viewController configuration:configuration completion:completion];
            
            if(!self.maintainSessionForListing) {
                [sftp.session disconnect];
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
                      completion:^( BOOL userInteractionRequired, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error ) {
        if ( userInteractionRequired ) {
            completion(kUpdateResultUserInteractionRequired, nil, error);
            return;
        }
        
        if(sftp == nil || error) {
            completion(kUpdateResultError, nil, error);
            return;
        }
        
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...") viewController:viewController];
        }
        
        BOOL atomicWrite = CrossPlatformDependencies.defaults.applicationPreferences.atomicSftpWrite;
        
        NSString* tmpFile = atomicWrite ? [NSString stringWithFormat:@"%@.%@.strongbox.tmp", providerData.filePath, NSUUID.UUID.UUIDString] : providerData.filePath;

        
        if(![sftp writeContents:data toFileAtPath:tmpFile progress:nil]) {
            if (viewController) {
                [self dismissProgressSpinner];
            }
            
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_update", @"Could not update file") errorCode:-3];
            completion(kUpdateResultError, nil, error);
        }
        else {
            if ( atomicWrite ) {
                NSString* tmpFile2 = [NSString stringWithFormat:@"%@.%@.strongbox.tmp", providerData.filePath, NSUUID.UUID.UUIDString];
                BOOL rename1 = [sftp renameFileAtPath:providerData.filePath to:tmpFile2];
                
                if ( rename1 ) {
                    BOOL rename2 = [sftp renameFileAtPath:tmpFile to:providerData.filePath];
                    
                    if ( rename2 ) {
                        
                        
                        BOOL deleteTmp = [sftp removeFileAtPath:tmpFile2];
                        if (!deleteTmp) {
                            slog(@"🔴 Could not cleanup temporary SFTP file!");
                        }
                        
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
                    else {
                        slog(@"🔴 SFTP: Rename 2 was not successful!");
                        
                        error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_update", @"Could not update file") errorCode:-3];
                        completion(kUpdateResultError, nil, error);
                    }
                }
                else {
                    slog(@"🔴 SFTP: Rename 1 was not successful!");
                    
                    error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_update", @"Could not update file") errorCode:-3];
                    completion(kUpdateResultError, nil, error);
                }
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
        }
        
        [sftp.session disconnect];
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
    
    if ( json != nil ) {
        NSData* data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSError* error;
        NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:kNilOptions
                                                                     error:&error];
        
        SFTPProviderData * foo = [SFTPProviderData fromSerializationDictionary:dictionary];
        
        return foo;
    }
    else {
        return nil;
    }
}

- (METADATA_PTR )getDatabasePreferences:(NSString *)nickName providerData:(NSObject *)providerData {
    SFTPProviderData* foo = (SFTPProviderData*)providerData;
    
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
                                                                     fileName:[foo.filePath lastPathComponent]
                                                               fileIdentifier:json];
    
    ret.lazySyncMode = YES; 
#else
    NSURLComponents* components = [[NSURLComponents alloc] init];
    components.scheme = kStrongboxSFTPUrlScheme;
    components.path = [foo.filePath hasPrefix:@"/"] ? foo.filePath : [@"/" stringByAppendingString:foo.filePath]; 
    slog(@"%@", components.URL);
    
    
    
    MacDatabasePreferences *ret = [MacDatabasePreferences templateDummyWithNickName:nickName
                                                                    storageProvider:self.storageId
                                                                            fileUrl:components.URL
                                                                        storageInfo:json];
    
    
    
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"uuid" value:ret.uuid]];
    
    ret.fileUrl = components.URL;
#endif
    
    return ret;
}

- (void)pullDatabase:(METADATA_PTR)safeMetaData
       interactiveVC:(VIEW_CONTROLLER_PTR )viewController
             options:(StorageProviderReadOptions     *)options
          completion:(StorageProviderReadCompletionBlock)completion {
    SFTPProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self readWithProviderData:providerData viewController:viewController options:options completion:completion];
}

- (void)getModDate:(METADATA_PTR)safeMetaData
        completion:(StorageProviderGetModDateCompletionBlock)completion {
    SFTPProviderData* foo = [self getProviderDataFromMetaData:safeMetaData];
    SFTPSessionConfiguration* connection = [self getConnectionFromProviderData:foo];
    
    if ( !connection ) {
        NSError* error = [Utils createNSError:@"Could not load connection!" errorCode:-322243];
        completion(YES, nil, error );
        return;
    }
    
    
    
    
    [self connectAndAuthenticate:connection
                  viewController:nil
                      completion:^(BOOL userInteractionRequired, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if ( sftp == nil || error) {
            completion(YES, nil, error);
            return;
        }
        
        NMSFTPFile* attr = [sftp infoForFileAtPath:foo.filePath];
        if ( !attr ) {
            [sftp.session disconnect];
            
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            completion(YES, nil, error);
            return;
        }
        
        
        [sftp.session disconnect];
        
        
        
        completion(YES, attr.modificationDate, nil);
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
                      completion:^(BOOL userInteractionRequired, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if ( userInteractionRequired ) {
            completionHandler(kReadResultBackgroundReadButUserInteractionRequired, nil, nil, error);
            return;
        }
        
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
            [sftp.session disconnect];
            
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        if (options.onlyIfModifiedDifferentFrom && [options.onlyIfModifiedDifferentFrom isEqualToDateWithinEpsilon:attr.modificationDate]) {
            if (viewController) {
                [self dismissProgressSpinner];
            }
            
            [sftp.session disconnect];
            NMSSHSession *sess = [sftp session];
            [sess disconnect];
            
            completionHandler(kReadResultModifiedIsSameAsLocal, nil, nil, error);
            return;
        }
        
        NSData* data = [sftp contentsAtPath:foo.filePath];
        
        if (viewController) {
            [self dismissProgressSpinner];
        }
        
        if(!data) {
            error = [Utils createNSError:NSLocalizedString(@"sftp_provider_could_not_read", @"Could not read file") errorCode:-3];
            
            [sftp.session disconnect];
            
            completionHandler(kReadResultError, nil, nil, error);
            return;
        }
        
        [sftp.session disconnect];
        
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
                    completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, SFTPSessionConfiguration* configuration, NSError* error))completion {
    
    
    
    
    sessionConfiguration = sessionConfiguration ? sessionConfiguration : self.explicitConnection;
    
    [self connectAndAuthenticateWithSessionConfiguration:sessionConfiguration
                                          viewController:viewController
                                              completion:^(BOOL userInteractionRequired, NMSFTP *sftp, NSError *error) {
        completion(userInteractionRequired, sftp, sessionConfiguration, error);
    }];
}

- (void)connectAndAuthenticateWithSessionConfiguration:(SFTPSessionConfiguration*)sessionConfiguration
                                        viewController:(VIEW_CONTROLLER_PTR)viewController
                                            completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    
    NSError* error;
    
    if ( ( sessionConfiguration.authenticationMode == kPrivateKey && sessionConfiguration.privateKey == nil ) || ( sessionConfiguration.authenticationMode == kUsernamePassword && sessionConfiguration.password == nil ) ) {
        
        NSString* loc = NSLocalizedString(@"password_unavailable_please_edit_connection_error", @"Your private key or password is no longer available, probably because you've just migrated to a new device.\nPlease edit your connection to fix.");
        
        error = [Utils createNSError:loc errorCode:kStorageProviderSFTPorWebDAVSecretMissingErrorCode];
        completion(NO, nil, error);
        return;
    }
    
    if (viewController) {
        [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating_connecting", @"Connecting...")
                   viewController:viewController];
    }
    
    NMSSHSession *session = nil;
    @try {
        session = [[NMSSHSession alloc] initWithHost:sessionConfiguration.host andUsername:sessionConfiguration.username];
        NSString* errorString = @"";
        if ( ![session connectWithTimeout:@(10) errorString:&errorString] ) {
            error = [Utils createNSError:errorString errorCode:-1234];
            completion(NO, nil, error);
            return;
        }
    } @catch (NSException *exception) {
        slog(@"WARNWARN: SSH Connect Exception: %@", exception);
        error = [Utils createNSError:exception.reason errorCode:-1234];
        completion(NO, nil, error);
        return;
    } @finally {
        if (viewController) {
            [self dismissProgressSpinner];
        }
    }
    
    [self fingerPrintCheck:sessionConfiguration session:session viewController:viewController completion:completion];
}

- (void)fingerPrintCheck:(SFTPSessionConfiguration*)sessionConfiguration
                 session:(NMSSHSession*)session
          viewController:(VIEW_CONTROLLER_PTR)viewController
              completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    NSString* fingerprint = [session fingerprint:NMSSHSessionHashSHA256];
    
    if ( ![fingerprint isEqualToString:sessionConfiguration.sha256FingerPrint] ) {
        if ( viewController ) {
            if ( sessionConfiguration.sha256FingerPrint == nil ) {
                slog(@"⚠️ shouldConnectToHostWithFingerprint NO EXISTING FINGERPRINT: [%@]", fingerprint);

                [self promptUserOnFirstUseFingerPrint:sessionConfiguration
                                              session:session
                                          fingerprint:fingerprint
                                       viewController:viewController
                                           completion:completion];
            }
            else {
                slog(@"🔴 WARNWARN: shouldConnectToHostWithFingerprint does NOT match: [%@]", fingerprint);

                [self promptUserOnFingerPrintChange:sessionConfiguration
                                            session:session
                                        fingerprint:fingerprint
                                     viewController:viewController
                                         completion:completion];
            }
        }
        else {
            slog(@"🔴 Fingerprint Check failed but in background / non-interactive mode... Failing");
            [session disconnect];
            NSError* error = [Utils createNSError:@"Fingerprint Check failed but in background / non-interactive mode... Aborting Connection." errorCode:-1222333];
            completion ( YES, nil, error );
        }
    }
    else {

        [self continueWithAuthenticationInBackground:sessionConfiguration session:session viewController:viewController completion:completion];
    }
}

- (void)promptUserOnFirstUseFingerPrint:(SFTPSessionConfiguration*)sessionConfiguration
                                session:(NMSSHSession*)session
                            fingerprint:(NSString*)fingerprint
                         viewController:(VIEW_CONTROLLER_PTR)viewController
                             completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    NSString* fmt = NSLocalizedString(@"sftp_hostkey_fingerprint_first_use_confirm_fmt", @"The SFTP host returned the Fingerprint below.\n\nStrongbox will use this Fingerprint to verify it is commumicating with only this host.\n\nPlease confirm you are happy with this Fingerprint, you will be notified if it changes.\n\n%@");
    
    [self promptUserOnFingerPrintChangeOrFirstUse:sessionConfiguration
                                          message:fmt
                                          session:session
                                      fingerprint:fingerprint
                                   viewController:viewController
                                       completion:completion];
}

- (void)promptUserOnFingerPrintChange:(SFTPSessionConfiguration*)sessionConfiguration
                              session:(NMSSHSession*)session
                          fingerprint:(NSString*)fingerprint
                       viewController:(VIEW_CONTROLLER_PTR)viewController
                           completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    
    NSString* fmt = NSLocalizedString(@"sftp_hostkey_fingerprint_has_changed_confirm_fmt", @"*** WARNING ***\n\nThe SFTP host returned a different Fingerprint than expected.\n\nThis could be a man-in-the-middle attack, or it could be something you expect if your host configuration recently changed.\n\nShould Strongbox use this new Fingerprint and continue connecting to this host?\n\n%@");

    [self promptUserOnFingerPrintChangeOrFirstUse:sessionConfiguration
                                          message:fmt
                                          session:session
                                      fingerprint:fingerprint
                                   viewController:viewController
                                       completion:completion];
}

- (void)promptUserOnFingerPrintChangeOrFirstUse:(SFTPSessionConfiguration*)sessionConfiguration
                                        message:(NSString*)message
                                        session:(NMSSHSession*)session
                                    fingerprint:(NSString*)fingerprint
                                 viewController:(VIEW_CONTROLLER_PTR)viewController
                                     completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    [self yesNoAlert:NSLocalizedString(@"sftp_hostkey_fingerprint_alert_title", @"SFTP Fingerprint")
             message:[NSString stringWithFormat:message, fingerprint]
      viewController:viewController
          completion:^(BOOL yesNo) {
        if ( yesNo ) {
            sessionConfiguration.sha256FingerPrint = fingerprint;
            [SFTPConnections.sharedInstance addOrUpdate:sessionConfiguration];
            
            [self continueWithAuthenticationInBackground:sessionConfiguration session:session viewController:viewController completion:completion];
        }
        else {
            [session disconnect];
            NSError* error = [Utils createNSError:@"🔴 Fingerprint Rejected by User... Aborting Connection." errorCode:-1222333];
            completion ( NO, nil, error );
        }
    }];
}

- (void)continueWithAuthenticationInBackground:(SFTPSessionConfiguration*)sessionConfiguration
                                       session:(NMSSHSession*)session
                                viewController:(VIEW_CONTROLLER_PTR)viewController
                                    completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    if ( NSThread.isMainThread ) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
            [self continueWithAuthenticationInBackground2:sessionConfiguration session:session viewController:viewController completion:completion];
        });
    }
    else {
        [self continueWithAuthenticationInBackground2:sessionConfiguration session:session viewController:viewController completion:completion];
    }
}

- (void)continueWithAuthenticationInBackground2:(SFTPSessionConfiguration*)sessionConfiguration
                                        session:(NMSSHSession*)session
                                 viewController:(VIEW_CONTROLLER_PTR)viewController
                                     completion:(void (^)(BOOL userInteractionRequired, NMSFTP* sftp, NSError* error))completion {
    NSError* error = nil;
    NMSFTP* sftp =  [self authenticateSession:sessionConfiguration session:session viewController:viewController error:&error];
    completion ( NO, sftp, error );
}
    
- (NMSFTP*)authenticateSession:(SFTPSessionConfiguration*)sessionConfiguration
                       session:(NMSSHSession*)session
                viewController:(VIEW_CONTROLLER_PTR)viewController
                         error:(NSError**)error {
    
    
    if (session.isConnected) {
        if (viewController) {
            [self showProgressSpinner:NSLocalizedString(@"storage_provider_status_authenticating", @"Authenticating...")
                       viewController:viewController];
        }
        
        
        
        if(sessionConfiguration.authenticationMode == kPrivateKey) {
            [session authenticateByInMemoryPublicKey:nil
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
        [self connectAndAuthenticateWithSessionConfiguration:connection
                                              viewController:viewController
                                                  completion:^(BOOL userInteractionRequired, NMSFTP *sftp, NSError *error) {
            completion(error);
        }];
    });
}

- (SFTPSessionConfiguration*)getConnectionFromProviderData:(SFTPProviderData*)provider {
    return [SFTPConnections.sharedInstance getById:provider.connectionIdentifier];
}

- (SFTPSessionConfiguration *)getConnectionFromDatabase:(METADATA_PTR)metaData {
    return [self getConnectionFromProviderData:[self getProviderDataFromMetaData:metaData]];
}

@end

