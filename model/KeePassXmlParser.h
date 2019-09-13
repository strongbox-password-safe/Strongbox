//
//  KeePassXmlParser.h
//  Strongbox
//
//  Created by Mark on 11/09/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlParser : NSObject

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

- (void)didStartElement:(NSString *)elementName
             attributes:(NSDictionary *_Nullable)attributeDict;

-(void)foundCharacters:(NSString *)string;

- (void)didEndElement:(NSString *)elementName;

@end

NS_ASSUME_NONNULL_END
