//
//  CredentialProviderViewController.h
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <AuthenticationServices/AuthenticationServices.h>
#import "Model.h"

@interface CredentialProviderViewController : ASCredentialProviderViewController

@property (nonatomic, strong) Model* viewModel;

@end
