//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HTMLElement : NSObject

- (instancetype)init NS_UNAVAILABLE;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSDictionary<NSString *, NSString *> *attributes;
@property (readonly, nonatomic) NSArray<HTMLElement *> *children;
@property (nullable, readonly, nonatomic) NSString *contents;

@end

@interface HTMLDocument : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString *)string;

@property (readonly, nonatomic, strong) NSArray<HTMLElement *> *children;

- (NSArray<HTMLElement *> *)query:(NSString *)xpath;

@end

NS_ASSUME_NONNULL_END

