//
//  Node+KeeAgentSSH.h
//  MacBox
//
//  Created by Strongbox on 26/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Node.h"
#import "KeeAgentSshKeyViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface Node (KeeAgentSSH) 

- (void)setKeeAgentSshKeyEnabled:(BOOL)enabled;
@property (nullable) KeeAgentSshKeyViewModel* keeAgentSshKeyViewModel;

@end

NS_ASSUME_NONNULL_END
