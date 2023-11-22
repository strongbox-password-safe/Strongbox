//
//  NodePasskey.m
//  Strongbox
//
//  Created by Strongbox on 03/09/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "Node+Passkey.h"
#import "Constants.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@implementation Node (Passkey)

- (Passkey *)passkey {
    Passkey* passkey = nil;
    
    StringValue *rp = self.fields.customFields[kPasskeyCustomFieldKeyRelyingParty];
    StringValue *credId = self.fields.customFields[kPasskeyCustomFieldKeyUserId];
    StringValue *pk = self.fields.customFields[kPasskeyCustomFieldKeyPrivateKeyPem];
    StringValue *userHandle = self.fields.customFields[kPasskeyCustomFieldKeyUserHandle];
    StringValue *usernameSv = self.fields.customFields[kPasskeyCustomFieldKeyUsername];
    
    NSString* username = (usernameSv) ? usernameSv.value : self.fields.username; 
    
    if ( rp && credId && pk && userHandle ) {
        passkey = [[Passkey alloc] initWithRelyingPartyId:rp.value
                                                 username:username
                                            userHandleB64:userHandle.value
                                          credentialIdB64:credId.value
                                            privateKeyPem:pk.value];
    }

    return passkey;
}

- (void)setPasskey:(Passkey *)passkey {
    if ( passkey ) {
        [self.fields setCustomField:kPasskeyCustomFieldKeyRelyingParty value:[StringValue valueWithString:passkey.relyingPartyId protected:NO]];
        [self.fields setCustomField:kPasskeyCustomFieldKeyUserId value:[StringValue valueWithString:passkey.credentialIdB64 protected:YES]];
        [self.fields setCustomField:kPasskeyCustomFieldKeyPrivateKeyPem value:[StringValue valueWithString:passkey.privateKeyPem protected:YES]];
        [self.fields setCustomField:kPasskeyCustomFieldKeyUserHandle value:[StringValue valueWithString:passkey.userHandleB64 protected:YES]];
        [self.fields setCustomField:kPasskeyCustomFieldKeyUsername value:[StringValue valueWithString:passkey.username protected:NO]];
    }
    else {
        [self.fields removeCustomField:kPasskeyCustomFieldKeyRelyingParty];
        [self.fields removeCustomField:kPasskeyCustomFieldKeyUserId];
        [self.fields removeCustomField:kPasskeyCustomFieldKeyPrivateKeyPem];
        [self.fields removeCustomField:kPasskeyCustomFieldKeyUserHandle];
        [self.fields removeCustomField:kPasskeyCustomFieldKeyUsername];
    }
}

@end
