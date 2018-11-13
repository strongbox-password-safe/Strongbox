//
//  KeePassXmlParserDelegate.h
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlParserDelegate : NSObject<NSXMLParserDelegate>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initV3Plaintext;

- (instancetype)initV4Plaintext;

- (instancetype)initV3WithProtectedStreamId:(uint32_t)innerRandomStreamId
                                        key:(nullable NSData*)protectedStreamKey;

- (instancetype)initV4WithProtectedStreamId:(uint32_t)innerRandomStreamId
                                        key:(nullable NSData*)protectedStreamKey;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
                                  context:(XmlProcessingContext*)context;

@property (nonatomic, readonly, nullable) RootXmlDomainObject* rootElement;

@end

NS_ASSUME_NONNULL_END
