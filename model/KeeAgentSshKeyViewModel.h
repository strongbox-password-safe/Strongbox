//
//  KeeAgentSshKeyViewModel.h
//  MacBox
//
//  Created by Strongbox on 29/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OpenSSHPrivateKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeeAgentSshKeyViewModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)withKey:(OpenSSHPrivateKey *)key filename:(NSString *)filename enabled:(BOOL)enabled;

@property (readonly) BOOL enabled;
@property (readonly) NSString* filename;
@property (readonly) OpenSSHPrivateKey *openSshKey;

- (BOOL)isEqualTo:(id _Nullable)object;
- (BOOL)isEqualToEx:(id)object testEnabled:(BOOL)testEnabled;

@end

NS_ASSUME_NONNULL_END
