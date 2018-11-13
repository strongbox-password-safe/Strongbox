//
//  Binary.m
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Binary.h"
#import "KeePassConstants.h"

@implementation Binary

- (instancetype)initWithContext:(XmlProcessingContext*)context
{
    if(self = [super initWithXmlElementName:kBinaryElementName context:context]) {
        self.key = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kKeyElementName context:context];
        self.value = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kValueElementName context:context];
    }
    
    return self;
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
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kBinaryElementName];
    
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
