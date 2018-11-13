//
//  V3BinariesList.m
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "V3BinariesList.h"
#import "KeePassConstants.h"

@implementation V3BinariesList

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kV3BinariesListElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.binaries = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kBinaryElementName]) {
        return [[V3Binary alloc] initWithXmlElementName:kBinaryElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kBinaryElementName]) {
        [self.binaries addObject:(V3Binary*)completedObject];
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kV3BinariesListElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    for (V3Binary *binary in self.binaries) {
        [ret.children addObject:[binary generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

@end
