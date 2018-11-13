//
//  KeePassFile.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "KeePassFile.h"
#import "KeePassDatabase.h"

@implementation KeePassFile

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kKeePassFileElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _root = [[Root alloc] initWithDefaultsAndInstantiatedChildren:context];
        _meta = [[Meta alloc] initWithDefaultsAndInstantiatedChildren:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kMetaElementName]) {
        return [[Meta alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kRootElementName]) {
        return [[Root alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kMetaElementName]) {
        _meta = (Meta*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kRootElementName]) {
        _root = (Root*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kKeePassFileElementName];

    ret.node = self.nonCustomisedXmlTree.node;
    
    if(self.meta) [ret.children addObject:[self.meta generateXmlTree]];
    if(self.root) [ret.children addObject:[self.root generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Meta = [%@]\nRoot = [%@]\nUnknown Children = [%@]", self.meta, self.root, self.nonCustomisedXmlTree.children];
}

@end
