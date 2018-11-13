//
//  CustomIcon.m
//  Strongbox
//
//  Created by Mark on 11/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CustomIcon.h"
#import "KeePassConstants.h"

@implementation CustomIcon

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kCustomIconElementName context:context]) {
        self.uuidElement = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:context];
        self.dataElement = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kCustomIconDataElementName context:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kUuidElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kUuidElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kCustomIconDataElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kCustomIconDataElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuidElement = (GenericTextUuidElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconDataElementName]) {
        self.dataElement = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kCustomIconElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.uuidElement generateXmlTree]];
    [ret.children addObject:[self.dataElement generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSUUID *)uuid {
    return self.uuidElement.uuid;
}

- (void)setUuid:(NSUUID *)uuid {
    if(uuid) {
        self.uuidElement.uuid = uuid;
    }
}

- (NSData *)data {
    return [[NSData alloc] initWithBase64EncodedString:self.dataElement.text options:kNilOptions];
}

-(void)setData:(NSData *)data {
    if(data) {
        self.dataElement.text = [data base64EncodedStringWithOptions:kNilOptions];
    }
}

@end
