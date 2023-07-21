//
//  KeeAgentSshKeyViewModel.m
//  MacBox
//
//  Created by Strongbox on 29/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import "KeeAgentSshKeyViewModel.h"

@implementation KeeAgentSshKeyViewModel // Immutable - Keep that way

+ (instancetype)withKey:(OpenSSHPrivateKey *)openSshKey filename:(NSString *)filename enabled:(BOOL)enabled {
    return [[KeeAgentSshKeyViewModel alloc] initWithKey:openSshKey filename:filename enabled:enabled];
}

- (instancetype)initWithKey:(OpenSSHPrivateKey *)openSshKey filename:(NSString *)filename enabled:(BOOL)enabled {
    self = [super init];
    
    if (self) {
        _openSshKey = openSshKey;
        _filename = filename;
        _enabled = enabled;
    }
    
    return self;
}

- (BOOL)isEqualTo:(id)object {
    return [self isEqualToEx:object testEnabled:YES];
}

- (BOOL)isEqualToEx:(id)object testEnabled:(BOOL)testEnabled {
    if (object == nil) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[KeeAgentSshKeyViewModel class]]) {
        return NO;
    }
    
    KeeAgentSshKeyViewModel* other = (KeeAgentSshKeyViewModel*)object;
    
    if ( ![self.filename isEqualToString:other.filename] ) {
        return NO;
    }
    
    if ( ![self.openSshKey isEqualTo:other.openSshKey] ) {
        return NO;
    }
    
    if ( testEnabled ) {
        if ( self.enabled != other.enabled ) {
            return NO;
        }
    }

    return YES;
}

@end
