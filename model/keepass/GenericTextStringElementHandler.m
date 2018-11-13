//
//  Generator.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "GenericTextStringElementHandler.h"

@implementation GenericTextStringElementHandler

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(nonnull XmlProcessingContext *)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.text = @"";
    }
    
    return self;
}

- (void)onCompleted {
    self.text = [self getXmlText];
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    ret.node.xmlText = self.text;
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return self.text;
}

@end
