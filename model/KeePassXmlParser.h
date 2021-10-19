//
//  KeePassXmlParser.h
//  Strongbox
//
//  Created by Mark on 11/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RootXmlDomainObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface KeePassXmlParser : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithProtectedStreamId:(uint32_t)innerRandomStreamId
                                      key:(nullable NSData*)protectedStreamKey
              sanityCheckStreamDecryption:(BOOL)sanityCheckStreamDecryption
                                  context:(XmlProcessingContext*)context;

@property (nonatomic, readonly, nullable) RootXmlDomainObject* rootElement;

- (void)didStartElement:(NSString *)elementName
             attributes:(NSDictionary *_Nullable)attributeDict;

- (void)foundCharacters:(NSString *)string;

- (void)didEndElement:(NSString *)elementName;

@property (readonly, nullable) NSError* error;
@property (readonly, nullable) NSError* decryptionProblem;

@end

NS_ASSUME_NONNULL_END
