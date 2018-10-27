//
//  XmlTree.m
//  Strongbox-iOS
//
//  Created by Mark on 19/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlTree.h"

@implementation XmlTree

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName {
    if(self = [super init]) {
        self.node = [[XmlItem alloc] initWithXmlElementName:xmlElementName];
        self.children = [NSMutableArray array];
    }
    
    return self;
}

- (NSArray*)checkableElements:(NSArray*)elements {
    // Strip out any empty String elements
    
    return [elements filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        XmlTree* item = (XmlTree*)evaluatedObject;
        
        if([item.node.xmlElementName isEqualToString:@"String"]) {
            NSArray<XmlTree*> *foo = [item.children filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                XmlTree* bar = (XmlTree*)evaluatedObject;
                return [bar.node.xmlElementName isEqualToString:@"Value"];
            }]];
            
            if(foo.count == 1) {
                if([foo objectAtIndex:0].node.xmlText.length == 0) {
                    return NO;
                }
            }
        }
        
        return YES;
    }]];
}

- (BOOL)isXmlEquivalent_UnitTestOnly:(XmlTree*)other {
    if(![self.node isXmlEquivalent:other.node]) {
        return NO;
    }
    
    NSArray* aCheckableElements = [self checkableElements:self.children];
    NSArray* bCheckableElements = [self checkableElements:other.children];

    if(aCheckableElements.count != bCheckableElements.count) {
        NSLog(@"Mismatching Children:\na=[%lu]\nb=[%lu]", (unsigned long)self.children.count, (unsigned long)other.children.count);
        return NO;
    }
    
    NSArray* a = [aCheckableElements sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        // NOTE: Generally it's only Group, Entry and String elements that can be multiple. If we happen to sort like
        // this then there is the possibility that we are comparing say the wrong group/entry and will get a False Negative...
        // Because we're generally maintaining order this seems to work ok for now. Only used for Unit Tests. Not for
        // Operational Use.
        
        return [((XmlTree*)obj1).node.xmlElementName compare:((XmlTree*)obj2).node.xmlElementName];
    }];

    NSArray* b = [bCheckableElements sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [((XmlTree*)obj1).node.xmlElementName compare:((XmlTree*)obj2).node.xmlElementName];
    }];
    
    for (int i=0; i<a.count; i++) {
        XmlTree* aTree = [a objectAtIndex:i];
        XmlTree* bTree = [b objectAtIndex:i];
        
        if(![aTree isXmlEquivalent_UnitTestOnly:bTree]) {
            NSLog(@"=========================================================================================");
            NSLog(@"Not Equivalent: [%@] != [%@]\n[%@]=[%@]", aTree.node.xmlElementName, bTree.node.xmlElementName, aTree, bTree);
            return NO;
        }
    }
    
    return YES;
}

-(NSString *)description {
    NSMutableString *children = [NSMutableString stringWithString:@"{\n"];
    
    for (NSString* child in self.children) {
        [children appendFormat:@"[%@],\n", child];
    }
    
    [children appendString:@"}"];
    
    return [NSString stringWithFormat:@"name = [%@]\nattributes = [%@]\ntext = [%@]", self.node.xmlElementName, self.node.xmlAttributes, self.node.xmlText];
}

@end
