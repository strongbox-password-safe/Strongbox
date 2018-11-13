//
//  CustomIconList.m
//  Strongbox
//
//  Created by Mark on 11/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "CustomIconList.h"
#import "KeePassConstants.h"

@implementation CustomIconList

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kCustomIconListElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.icons = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kCustomIconElementName]) {
        return [[CustomIcon alloc] initWithXmlElementName:kCustomIconElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kCustomIconElementName]) {
        [self.icons addObject:(CustomIcon*)completedObject];
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kCustomIconListElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    for (CustomIcon *icon in self.icons) {
        [ret.children addObject:[icon generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

@end
