//
//  GenericTextBooleanElementHandler.m
//  Strongbox
//
//  Created by Mark on 20/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "GenericTextBooleanElementHandler.h"

@implementation GenericTextBooleanElementHandler 

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(XmlProcessingContext*)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.booleanValue = NO;
    }
    
    return self;
}

- (void)onCompleted {    
    NSString *str = [self getXmlText];
    
    if(str && str.length) {
        self.booleanValue = [str isEqualToString:@"True"];
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:self.nonCustomisedXmlTree.node.xmlElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    ret.node.xmlText = self.booleanValue ? @"True" : @"False";
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return self.booleanValue ? @"YES" : @"NO";
}

@end
