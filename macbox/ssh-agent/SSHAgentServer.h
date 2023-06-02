//
//  SSHAgentServer.h
//  MacBox
//
//  Created by Strongbox on 23/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSHAgentServer : NSObject

+ (instancetype)sharedInstance;

- (void)stop;
- (BOOL)start; 

@property (readonly) BOOL symlinkExists;
@property (readonly) BOOL isRunning;
@property (readonly, nullable) NSString* socketPathForSshConfig;

- (BOOL)createSymLink;


@end

NS_ASSUME_NONNULL_END
