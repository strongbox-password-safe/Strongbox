//
//  GenericTextIntegerElementHandler.m
//  Strongbox
//
//  Created by Mark on 08/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "GenericTextIntegerElementHandler.h"

@implementation GenericTextIntegerElementHandler

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.integer = 0;
    }
    
    return self;
}

- (void)onCompleted {
   self.integer = [[self getXmlText] integerValue];
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    ret.node.xmlText = @(self.integer).stringValue;

    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return @(self.integer).stringValue;
}

@end
