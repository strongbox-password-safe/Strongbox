//
//  KdfParameters.h
//  Strongbox
//
//  Created by Mark on 26/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KdfParameters : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUuid:(NSUUID*)uuid parameters:(NSDictionary<NSString*, NSObject*>*)parameters NS_DESIGNATED_INITIALIZER;
+ (instancetype)fromHeaders:(NSDictionary<NSString*, NSObject*>*)headers;
    
@property (nonatomic) NSUUID* uuid;
@property (nonatomic) NSDictionary<NSString*, NSObject*>* parameters;

@end

NS_ASSUME_NONNULL_END
