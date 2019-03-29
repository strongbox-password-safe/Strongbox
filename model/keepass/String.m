//
//  String.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "String.h"
#import "KeePassDatabase.h"

@interface String ()

@property GenericTextStringElementHandler* keyElement;
@property GenericTextStringElementHandler* valueElement;

@end

@implementation String

- (instancetype)initWithContext:(XmlProcessingContext*)context
{
    if(self = [super initWithXmlElementName:kStringElementName context:context]) {
        self.keyElement = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kKeyElementName context:context];
        self.valueElement = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kValueElementName context:context];
    }

    return self;
}

- (instancetype)initWithKey:(NSString *)key value:(NSString *)value protected:(BOOL)protected context:(XmlProcessingContext*)context {
    String* ret = [[String alloc] initWithContext:context];
    
    ret.key = key;
    ret.value = value;
    ret.protected = protected;
    
    return ret;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kKeyElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kKeyElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kValueElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kValueElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeyElementName]) {
        self.keyElement = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    if([withXmlElementName isEqualToString:kValueElementName]) {
        self.valueElement = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    
    return NO;
}

- (NSString *)key {
    return self.keyElement.text;
}

- (void)setKey:(NSString *)key {
    [self.keyElement setText:key];
}

- (NSString *)value {
    return self.valueElement.text;
}

- (void)setValue:(NSString *)value {
    [self.valueElement setText:value];
}

- (BOOL)protected {
    NSString* attr = self.valueElement.nonCustomisedXmlTree.node.xmlAttributes[kAttributeProtected];
    
    return attr && [attr isEqualToString:kAttributeValueTrue];
}

- (void)setProtected:(BOOL)protected {
    self.valueElement.nonCustomisedXmlTree.node.xmlAttributes[kAttributeProtected] = protected ? kAttributeValueTrue : nil;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kStringElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    [ret.children addObject:[self.keyElement generateXmlTree]];
    
    XmlTree *foo = [self.valueElement generateXmlTree];
    foo.node.doNotTrimWhitespaceText = YES; // Don't trim Values - Whitespace might be important...
    
    [ret.children addObject:foo];
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ [%@] = [%@] }", self.key, self.value];
}

@end
