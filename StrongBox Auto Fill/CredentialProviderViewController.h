//
//  CredentialProviderViewController.h
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <AuthenticationServices/AuthenticationServices.h>
#import "StorageProvider.h"
#import "SafeMetaData.h"

@interface CredentialProviderViewController : ASCredentialProviderViewController

- (void)showQuickLaunchView;
- (void)showSafesListView;
- (SafeMetaData*)getPrimarySafe;
- (BOOL)isUnsupportedAutoFillProvider:(StorageProvider)storageProvider;
- (NSArray<ASCredentialServiceIdentifier *> *)getCredentialServiceIdentifiers;
- (IBAction)cancel:(id)sender;

@end
