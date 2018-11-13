//
//  GenericTextUuidElementHandler.m
//  Strongbox
//
//  Created by Mark on 21/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "GenericTextUuidElementHandler.h"

@implementation GenericTextUuidElementHandler

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.uuid = [NSUUID UUID];
    }
    
    return self;
}

- (void)onCompleted {
    NSData *uuidData = [[NSData alloc] initWithBase64EncodedString:[self getXmlText] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(uuidData && uuidData.length == sizeof(uuid_t)) {
        self.uuid = [[NSUUID alloc] initWithUUIDBytes:uuidData.bytes];
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    uuid_t rawUuid;
    [self.uuid getUUIDBytes:(uint8_t*)&rawUuid];
    
    NSData *dataUuid = [NSData dataWithBytes:&rawUuid length:sizeof(uuid_t)];
    ret.node.xmlText = [dataUuid base64EncodedStringWithOptions:kNilOptions];
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [self.uuid UUIDString];
}

@end
