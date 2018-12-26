//
//  SFTPStorageProvider.m
//  Strongbox
//
//  Created by Mark on 11/12/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "SFTPStorageProvider.h"
#import "Utils.h"
#import "NMSSH.h"
#import "Settings.h"
#import "NSArray+Extensions.h"
#import "SFTPProviderData.h"
#import "SFTPSessionConfigurationViewController.h"
#import "SVProgressHUD.h"

@interface SFTPStorageProvider ()

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
    if([super init]) {
        _displayName = @"SFTP";
        _icon = @"sftp-32x32"; 
        _storageId = kSFTP;
        _cloudBased = YES;
        _providesIcons = NO;
        _browsableNew = YES;
        _browsableExisting = YES;
        _rootFolderOnly = NO;
    }
    
    return self;
}

- (void)create:(NSString *)nickName
     extension:(NSString *)extension
          data:(NSData *)data
  parentFolder:(NSObject *)parentFolder
viewController:(UIViewController *)viewController
    completion:(void (^)(SafeMetaData *, NSError *))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListing) { // Create New
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
              completion:(void (^)(SafeMetaData *, NSError *))completion {
    NSString *desiredFilename = [NSString stringWithFormat:@"%@.%@", nickName, extension];
    NSString *dir = [self getDirectoryFromParentFolderObject:parentFolder];
    NSString *path = [NSString pathWithComponents:@[dir, desiredFilename]];

    if(![sftp writeContents:data toFileAtPath:path progress:nil]) {
        NSError* error = [Utils createNSError:@"Could not create file" errorCode:-3];
        completion(nil, error);
        return;
    }
    
    SFTPProviderData* providerData = makeProviderData(path, configuration);
    SafeMetaData *metadata = [self getSafeMetaData:nickName providerData:providerData];

    [sftp disconnect];

    completion(metadata, nil);
}

- (void)list:(NSObject *)parentFolder
viewController:(UIViewController *)viewController
  completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    if(self.maintainSessionForListing && self.maintainedSessionForListing) {
        [self listWithSftpSession:self.maintainedSessionForListing
                     parentFolder:parentFolder
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
                              
            [self listWithSftpSession:sftp parentFolder:parentFolder configuration:configuration completion:completion];
                              
            if(!self.maintainSessionForListing) {
                [sftp disconnect];
            }
        }];
    }
}

- (void)listWithSftpSession:(NMSFTP*)sftp
                        parentFolder:(NSObject *)parentFolder
                        configuration:(SFTPSessionConfiguration *)configuration
                          completion:(void (^)(BOOL, NSArray<StorageBrowserItem *> *, NSError *))completion {
    [SVProgressHUD showWithStatus:@"Listing..."];
    
    NSString * dir = [self getDirectoryFromParentFolderObject:parentFolder];
    
    NSArray<NMSFTPFile*>* files = [sftp contentsOfDirectoryAtPath:dir];
    
    [SVProgressHUD dismiss];
    
    NSArray<StorageBrowserItem*>* browserItems = [files map:^id _Nonnull(NMSFTPFile * _Nonnull obj, NSUInteger idx) {
        StorageBrowserItem* sbi = [[StorageBrowserItem alloc] init];
        sbi.name = obj.isDirectory && obj.filename.length > 1 ? [obj.filename substringToIndex:obj.filename.length-1] : obj.filename;
        sbi.folder = obj.isDirectory;
        NSString* path = [NSString pathWithComponents:@[dir, sbi.name]];
        sbi.providerData = makeProviderData(path, configuration);
        
        return sbi;
    }];
    
    completion(NO, browserItems, nil);
}

- (void)read:(SafeMetaData *)safeMetaData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *))completion {
    SFTPProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self readWithProviderData:providerData viewController:viewController completion:completion];
}

- (void)readWithProviderData:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(NSData *, NSError *))completionHandler {
    SFTPProviderData* foo = (SFTPProviderData*)providerData;
    [self connectAndAuthenticate:foo.sFtpConfiguration
                  viewController:viewController
                      completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if(sftp == nil || error) {
            completionHandler(nil, error);
            return;
        }
        
          dispatch_async(dispatch_get_main_queue(), ^{
              [SVProgressHUD showWithStatus:@"Reading..."];
          });
                          
        NSData* data = [sftp contentsAtPath:foo.filePath];
          dispatch_async(dispatch_get_main_queue(), ^{
              [SVProgressHUD dismiss];
          });
             
        if(!data) {
            error = [Utils createNSError:@"Could not read file" errorCode:-3];
            completionHandler(nil, error);
            return;
        }
        
        [sftp disconnect];
        
        completionHandler(data, nil);
    }];
}

- (void)update:(SafeMetaData *)safeMetaData data:(NSData *)data completion:(void (^)(NSError *))completion {
    SFTPProviderData* providerData = [self getProviderDataFromMetaData:safeMetaData];
    [self connectAndAuthenticate:providerData.sFtpConfiguration
                  viewController:nil
                      completion:^(BOOL userCancelled, NMSFTP *sftp, SFTPSessionConfiguration *configuration, NSError *error) {
        if(sftp == nil || error) {
            completion(error);
            return;
        }
        
        
        if(![sftp writeContents:data toFileAtPath:providerData.filePath progress:nil]) {
            error = [Utils createNSError:@"Could not update file" errorCode:-3];
            completion(error);
            return;
        }
        
        [sftp disconnect];
        
        completion(nil);
    }];
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)delete:(SafeMetaData *)safeMetaData completion:(void (^)(NSError *))completion {
    // NOTIMPL
}

- (void)loadIcon:(NSObject *)providerData viewController:(UIViewController *)viewController completion:(void (^)(UIImage *))completionHandler {
    // NOTIMPL
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SFTPProviderData*)getProviderDataFromMetaData:(SafeMetaData*)metaData {
    NSString* json = metaData.fileIdentifier;
    
    NSError* error;
    NSDictionary* dictionary = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]  options:kNilOptions error:&error];
    
    SFTPProviderData* foo = [SFTPProviderData fromSerializationDictionary:dictionary];
    
    return foo;
}

- (SafeMetaData *)getSafeMetaData:(NSString *)nickName providerData:(NSObject *)providerData {
    SFTPProviderData* foo = (SFTPProviderData*)providerData;
    
    NSError* error;
    NSData* data = [NSJSONSerialization dataWithJSONObject:[foo serializationDictionary] options:0 error:&error];
    
    if(error) {
        NSLog(@"%@", error);
        return nil;
    }
    
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return [[SafeMetaData alloc] initWithNickName:nickName
                                  storageProvider:self.storageId
                                         fileName:[foo.filePath lastPathComponent]
                                   fileIdentifier:json];
}

- (NSString *)getDirectoryFromParentFolderObject:(NSObject *)parentFolder {
    SFTPProviderData* parent = (SFTPProviderData*)parentFolder;
    NSString* dir = parent ? parent.filePath : @"/";
    return dir;
}

- (void)connectAndAuthenticate:(SFTPSessionConfiguration*)sessionConfiguration
                viewController:(UIViewController*)viewController
                    completion:(void (^)(BOOL userCancelled, NMSFTP* sftp, SFTPSessionConfiguration* configuration, NSError* error))completion {
    // 1. Use the specified Session if available, otherwise
    // 2. Use the current/last session if available, otherwise
    // 3. Ask for a session config and use that...
    
    if(sessionConfiguration == nil) {
        if(self.unitTestingSessionConfiguration != nil) {
            sessionConfiguration = self.unitTestingSessionConfiguration;
        }
        else {
            SFTPSessionConfigurationViewController *vc = [[SFTPSessionConfigurationViewController alloc] init];
            __weak SFTPSessionConfigurationViewController* weakRef = vc;
            vc.onDone = ^(BOOL success) {
                [viewController dismissViewControllerAnimated:YES completion:^{
                    if(success) {
                        NSError* error;
                        NMSFTP* sftp = [self connectAndAuthenticateWithSessionConfiguration:weakRef.configuration error:&error];
                        completion(NO, sftp, weakRef.configuration, error);
                    }
                    else {
                        completion(YES, nil, nil, nil);
                    }
                }];
            };
            
            [viewController presentViewController:vc animated:YES completion:nil];
            return;
        }
    }
    
    NSError* error;
    NMSFTP* sftp = [self connectAndAuthenticateWithSessionConfiguration:sessionConfiguration error:&error];
    self.unitTestingSessionConfiguration = sessionConfiguration;
    completion(NO, sftp, sessionConfiguration, error);
}

- (NMSFTP*)connectAndAuthenticateWithSessionConfiguration:(SFTPSessionConfiguration*)sessionConfiguration
                                                    error:(NSError**)error {
    NSLog(@"Connecting to %@", sessionConfiguration.host);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:@"Connecting..."];
    });
    
    NMSSHSession *session = [NMSSHSession connectToHost:sessionConfiguration.host
                                           withUsername:sessionConfiguration.username];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
    });
    
    if (session.isConnected) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:@"Authenticating..."];
        });
        
        if(sessionConfiguration.authenticationMode == kPrivateKey) {
            [session authenticateByInMemoryPublicKey:sessionConfiguration.publicKey
                                          privateKey:sessionConfiguration.privateKey
                                         andPassword:sessionConfiguration.password];
        }
        else {
            [session authenticateByPassword:sessionConfiguration.password];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });

        if (!session.isAuthorized) {
            if(error) {
                *error = [Utils createNSError:[NSString stringWithFormat:@"Authentication Failed for [user: %@]", sessionConfiguration.username] errorCode:-2];
            }
            return nil;
        }
    }
    else {
        if(error) {
            *error = [Utils createNSError:[NSString stringWithFormat:@"Could not connect to host: %@ [user: %@]",
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
    providerData.sFtpConfiguration = sftpConfiguration;
    
    return providerData;
}

@end
