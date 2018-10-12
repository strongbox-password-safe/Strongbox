//
//  CredentialProviderViewController.m
//  Strongbox Auto Fill
//
//  Created by Mark on 11/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CredentialProviderViewController.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"

@implementation CredentialProviderViewController

-(void)viewDidLoad {
    [super viewDidLoad];

    [self.viewModel.rootGroup.children map:^id _Nonnull(Node * _Nonnull obj, NSUInteger idx) {
        NSLog(@"%@", obj.title);
        return obj.title;
    }];
}

/*
 Prepare your UI to list available credentials for the user to choose from. The items in
 'serviceIdentifiers' describe the service the user is logging in to, so your extension can
 prioritize the most relevant credentials in the list.
*/
- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
    NSLog(@"Hi! %@", serviceIdentifiers);
    
    NSLog(@"%@", SafesList.sharedInstance.snapshot);
    
//    var hint : String? = nil;
//    if(serviceIdentifiers.first != nil) {
//        let firstIdentifier = serviceIdentifiers.first!
//        
//        if(firstIdentifier.type == ASCredentialServiceIdentifier.IdentifierType.URL) {
//            let url = NSURL(string: firstIdentifier.identifier)!
//            
//            print (url.host!)
//            
//            hint = url.host!
//        }
//        
//        dump(SafesList.sharedInstance()?.snapshot)
//        
//        //let foo : SafesList? = nil
//        
//        hint = serviceIdentifiers.first?.identifier
//    }
}

/*
 Implement this method if your extension supports showing credentials in the QuickType bar.
 When the user selects a credential from your app, this method will be called with the
 ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
 Provide the password by completing the extension request with the associated ASPasswordCredential.
 If using the credential would require showing custom UI for authenticating the user, cancel
 the request with error code ASExtensionErrorCodeUserInteractionRequired.

- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
    BOOL databaseIsUnlocked = YES;
    if (databaseIsUnlocked) {
        ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:@"j_appleseed" password:@"apple1234"];
        [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
    } else
        [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserInteractionRequired userInfo:nil]];
}
*/

/*
 Implement this method if -provideCredentialWithoutUserInteractionForIdentity: can fail with
 ASExtensionErrorCodeUserInteractionRequired. In this case, the system may present your extension's
 UI and call this method. Show appropriate UI for authenticating the user then provide the password
 by completing the extension request with the associated ASPasswordCredential.

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
}
*/

- (IBAction)cancel:(id)sender
{
    [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:ASExtensionErrorDomain code:ASExtensionErrorCodeUserCanceled userInfo:nil]];
}

- (IBAction)passwordSelected:(id)sender
{
    ASPasswordCredential *credential = [[ASPasswordCredential alloc] initWithUser:@"j_appleseed" password:@"apple1234"];
    [self.extensionContext completeRequestWithSelectedCredential:credential completionHandler:nil];
}

@end
