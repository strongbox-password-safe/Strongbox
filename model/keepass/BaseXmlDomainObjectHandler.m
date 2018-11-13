//
//  RootHandler.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "XmlTree.h"

@interface BaseXmlDomainObjectHandler ()

@end

@implementation BaseXmlDomainObjectHandler

- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];

    return nil;
//    return [self initWithXmlElementName:@"<DUMMY - Unreachable>" context:nil];
}

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(nonnull XmlProcessingContext *)context {
    if(self = [super init]) {
        self.nonCustomisedXmlTree = [[XmlTree alloc] initWithXmlElementName:xmlElementName];
        
        if(!context) {
            NSLog(@"Parsing Context cannot be nil.");
            [NSException raise:NSInternalInconsistencyException
                        format:@"Parsing Context cannot be nil %@ in a subclass", NSStringFromSelector(_cmd)];
            return nil;
        }
        
        self.context = context;
    }

    return self;
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    return NO; // We don't know any specific child objects, returning NO leads to a call to the above addUnknownChildObject
}

- (void)addUnknownChildObject:(XmlTree*)xmlTree {
    [self.nonCustomisedXmlTree.children addObject:xmlTree];
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    return nil; // We don't have any special child handlers, returning nil here just leads to us being used again anyway
}

- (void)setXmlInfo:(nonnull NSString *)elementName attributes:(nonnull NSDictionary *)attributes {
    self.nonCustomisedXmlTree.node.xmlElementName = elementName;
    [self.nonCustomisedXmlTree.node.xmlAttributes addEntriesFromDictionary:attributes];
}

- (void)setXmlInfo:(nonnull NSString *)elementName
        attributes:(nonnull NSDictionary *)attributes
              text:(nonnull NSString *)text {
    self.nonCustomisedXmlTree.node.xmlElementName = elementName;
    [self.nonCustomisedXmlTree.node.xmlAttributes addEntriesFromDictionary:attributes];
    self.nonCustomisedXmlTree.node.xmlText = text;
}

- (nonnull XmlTree *)generateXmlTree {
    return self.nonCustomisedXmlTree;
}

- (void)setXmlAttribute:(nonnull NSString *)key value:(nonnull NSString *)value {
    [self.nonCustomisedXmlTree.node.xmlAttributes setValue:value forKey:key];
}

- (void)appendXmlText:(nonnull NSString *)text {
    self.nonCustomisedXmlTree.node.xmlText = [NSString stringWithFormat:@"%@%@", self.nonCustomisedXmlTree.node.xmlText,text];
}


- (nonnull NSString *)getXmlText {
    return self.nonCustomisedXmlTree.node.xmlText;
}

- (void)onCompleted { }

- (void)setXmlText:(nonnull NSString *)text {
    self.nonCustomisedXmlTree.node.xmlText = text;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", self.nonCustomisedXmlTree];
}

@end
