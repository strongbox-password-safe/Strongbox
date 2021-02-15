//
//  XmlToDictionaryParser.m
//  StrongboxTests
//
//  Created by Mark on 03/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "XmlToDictionaryParser.h"

@interface XmlToDictionaryParser ()

@property NSMutableString* mutableText;
@property NSMutableArray<XmlComparisonElement*> *elementStack;

@end

@implementation XmlToDictionaryParser

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mutableText = [NSMutableString string];
        self.elementStack = @[[[XmlComparisonElement alloc] initWithElementName:@"DUMMY" attributes:nil]].mutableCopy;
    }
    return self;
}

- (XmlComparisonElement *)rootElement {
    return self.elementStack.firstObject;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict {
    if(self.mutableText.length) {
        [self.mutableText setString:@""];
    }

    XmlComparisonElement* element = [[XmlComparisonElement alloc] initWithElementName:elementName attributes:attributeDict];
    [self.elementStack addObject:element];
}

-(void) parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [self.mutableText appendString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    XmlComparisonElement* element = self.elementStack.lastObject;
    if (self.mutableText.length) {
        element.text = self.mutableText.copy;
        [self.mutableText setString:@""];
    }
    
    [self.elementStack removeLastObject];
    XmlComparisonElement* parentElement = self.elementStack.lastObject;
    
    if(parentElement) {
        [parentElement.children addObject:element];
    }
}


@end
