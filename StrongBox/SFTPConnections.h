//
//  SFTPConnections.h
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SFTPSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SFTPConnections : NSObject

+ (instancetype)sharedInstance;

- (SFTPSessionConfiguration*)getById:(NSString*)identifier;
- (void)addOrUpdate:(SFTPSessionConfiguration*)key;
- (void)deleteConnection:(NSString*)identifier;

- (NSArray<SFTPSessionConfiguration*>*)snapshot;

@end

NS_ASSUME_NONNULL_END
