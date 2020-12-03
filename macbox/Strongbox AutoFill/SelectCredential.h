//
//  SelectCredential.h
//  Strongbox AutoFill
//
//  Created by Strongbox on 26/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DatabaseMetadata.h"
#import "DatabaseModel.h"
#import <AuthenticationServices/AuthenticationServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface SelectCredential : NSViewController

@property NSArray<ASCredentialServiceIdentifier *>* serviceIdentifiers;
@property DatabaseModel* model;
@property (nonatomic, copy) void (^onDone)(BOOL userCancelled,  NSString*_Nullable username, NSString*_Nullable password, NSString*_Nullable totp);

@end

NS_ASSUME_NONNULL_END
