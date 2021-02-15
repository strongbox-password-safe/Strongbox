//
//  HibpOperation.h
//  Strongbox
//
//  Created by Strongbox on 02/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UrlRequestOperation : NSOperation

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithRequest:(NSURLRequest *)request dataTaskCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))dataTaskCompletionHandler NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)url dataTaskCompletionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))dataTaskCompletionHandler;

@end

NS_ASSUME_NONNULL_END
