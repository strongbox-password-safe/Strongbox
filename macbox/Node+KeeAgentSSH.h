//
//  Node+KeeAgentSSH.h
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface Node (KeeAgentSSH)

@property (readonly) BOOL hasKeeAgentSshPrivateKey;
@property (readonly) BOOL hasEnabledKeeAgentSshPrivateKey;

@property (readonly, nullable) NSData* keeAgentSshPrivateKeyData;
@property (readonly, nullable) NSData* keeAgentEnabledSshPrivateKeyData;
@property (readonly, nullable) NSString* keeAgentSshKeyAttachmentName;

- (void)removeKeeAgentSshKey;
- (void)addKey:(NSString*)filename keyFileBlob:(NSData*)keyFileBlob enabled:(BOOL)enabled;
- (void)setKeeAgentSshPrivateKeyEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
