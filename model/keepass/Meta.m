//
//  Meta.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Meta.h"
#import "KeePassDatabase.h"

@implementation Meta

- (instancetype)init {
    return [super initWithXmlElementName:kMetaElementName];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren {
    self = [self init];
    
    if(self) {
        _generator = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kGeneratorElementName];
        self.generator.text = kDefaultGenerator;
    }
    
    return self;
}

- (void)setHash:(NSString*)hash {
    if(!self.headerHash) {
        self.headerHash = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kHeaderHashElementName];
    }
    
    self.headerHash.text = hash;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGeneratorElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kGeneratorElementName];
    }
    else if ([xmlElementName isEqualToString:kHeaderHashElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kHeaderHashElementName];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGeneratorElementName]) {
        self.generator = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    if([withXmlElementName isEqualToString:kHeaderHashElementName]) {
        self.headerHash = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kMetaElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    if(self.generator) [ret.children addObject:[self.generator generateXmlTree]];
    if(self.headerHash) [ret.children addObject:[self.headerHash generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Generator = [%@]\nHeader Hash=[%@]\nUnknown Children = [%@]", self.generator, self.headerHash, self.nonCustomisedXmlTree.children];
}

@end
