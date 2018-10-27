//
//  XmlTreeSerializer.h
//  Strongbox
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlTree.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlTreeSerializer : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPrettyPrint:(BOOL)prettyPrint;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                    b64ProtectedStreamKey:(NSString*)b64ProtectedStreamKey
                              prettyPrint:(BOOL)prettyPrint;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
                              prettyPrint:(BOOL)prettyPrint NS_DESIGNATED_INITIALIZER;

- (nullable NSString*)serializeTrees:(NSArray<XmlTree*>*)trees;
- (nullable NSString*)serializeTree:(XmlTree*)tree;

@property (nonatomic, readonly) NSData* protectedStreamKey;

@end

NS_ASSUME_NONNULL_END
