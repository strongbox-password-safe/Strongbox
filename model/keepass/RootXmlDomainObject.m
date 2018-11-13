//
//  RootXmlDomainObject.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "RootXmlDomainObject.h"
#import "KeePassFile.h"
#import "KeePassDatabase.h"

@implementation RootXmlDomainObject

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return self = [super initWithXmlElementName:@"Dummy" context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _keePassFile = [[KeePassFile alloc] initWithDefaultsAndInstantiatedChildren:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kKeePassFileElementName]) {
        return [[KeePassFile alloc] initWithXmlElementName:kKeePassFileElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeePassFileElementName]) {
        _keePassFile = (KeePassFile*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:@"Dummy"];
    
    ret.node = self.nonCustomisedXmlTree.node;
   
    if(self.keePassFile) [ret.children addObject:[self.keePassFile generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"KeePassFile = [%@]\nUnknown Children = [%@]", self.keePassFile, self.nonCustomisedXmlTree.children];
}

@end
