//
//  String.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "String.h"
#import "KeePassDatabase.h"

@implementation String

- (instancetype)init
{
    if(self = [super initWithXmlElementName:kStringElementName]) {
        self.key = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kKeyElementName];
        self.value = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kValueElementName];
    }

    return self;
}

- (instancetype)initWithProtectedValue:(BOOL)protected
{
    if(self = [self init]) {
        if(protected) {
            [self.value setXmlAttribute:kAttributeProtected value:kAttributeValueTrue];
        }
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kKeyElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kKeyElementName];
    }
    else if([xmlElementName isEqualToString:kValueElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kValueElementName];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeyElementName]) {
        self.key = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    if([withXmlElementName isEqualToString:kValueElementName]) {
        self.value = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kStringElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    [ret.children addObject:[self.key generateXmlTree]];
    [ret.children addObject:[self.value generateXmlTree]];

    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ [%@] = [%@] }", self.key, self.value];
}

@end
