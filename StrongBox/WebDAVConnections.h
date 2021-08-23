//
//  WebDAVConnections.h
//  Strongbox
//
//  Created by Strongbox on 02/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebDAVSessionConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebDAVConnections : NSObject

+ (instancetype)sharedInstance;

- (WebDAVSessionConfiguration*)getById:(NSString*)identifier;
- (void)addOrUpdate:(WebDAVSessionConfiguration*)key;
- (void)deleteConnection:(NSString*)identifier;

- (NSArray<WebDAVSessionConfiguration*>*)snapshot;

@end

NS_ASSUME_NONNULL_END
