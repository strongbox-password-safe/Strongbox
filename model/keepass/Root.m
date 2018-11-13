//
//  Root.m
//  Strongbox
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Root.h"
#import "KeePassDatabase.h"

@implementation Root

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return self = [super initWithXmlElementName:kRootElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _rootGroup = [[KeePassGroup alloc] initAsKeePassRoot:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        if(self.rootGroup == nil) {
            // Little extra safety here in case somehow multiple root groups exist,
            // we only look at the first (which is I believe how the model works. If
            // somehow this isn't the case, we will not overwrite the other groups but just ignore them
            
            return [[KeePassGroup alloc] initWithContext:self.context];
        }
        else {
            NSLog(@"WARN: Multiple Root Groups found. Ignoring extra.");
        }
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGroupElementName] && self.rootGroup == nil) {
        _rootGroup = (KeePassGroup*)completedObject;
        return YES;
    }
  
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kRootElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;

    if(self.rootGroup) {
        [ret.children addObject:[self.rootGroup generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];

    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Root Group = [%@]\nUnknown Children = [%@]", self.rootGroup, self.nonCustomisedXmlTree.children];
}

@end
