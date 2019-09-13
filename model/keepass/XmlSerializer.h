//
//  XmlTreeSerializer.h
//  Strongbox
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XmlParsingDomainObject.h"
#import "IXmlSerializer.h"

NS_ASSUME_NONNULL_BEGIN

@interface XmlSerializer : NSObject<IXmlSerializer>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPrettyPrint:(BOOL)prettyPrint v4Format:(BOOL)v4Format;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                    b64ProtectedStreamKey:(NSString*)b64ProtectedStreamKey
                                 v4Format:(BOOL)v4Format
                              prettyPrint:(BOOL)prettyPrint;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
                                 v4Format:(BOOL)v4Format
                              prettyPrint:(BOOL)prettyPrint NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSData* protectedStreamKey;
                                
@end

NS_ASSUME_NONNULL_END
