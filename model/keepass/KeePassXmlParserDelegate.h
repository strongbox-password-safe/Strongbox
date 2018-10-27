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
- (instancetype)initPlaintext;
- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId key:(nullable NSData*)protectedStreamKey NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly, nullable) RootXmlDomainObject* rootElement;

@end

NS_ASSUME_NONNULL_END
