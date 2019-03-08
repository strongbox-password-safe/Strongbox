//
//  History.m
//  Strongbox
//
//  Created by Mark on 07/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "History.h"
#import "KeePassConstants.h"
#import "Entry.h"

@implementation History

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kHistoryElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.entries = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
//    if([xmlElementName isEqualToString:kEntryElementName]) {
//        return [[Entry alloc] initWithXmlElementName:kEntryElementName context:self.context];
//    }
    if([xmlElementName isEqualToString:kEntryElementName]) {
        return [[Entry alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kEntryElementName]) {
        [self.entries addObject:(Entry*)completedObject];
        return YES;
    }

    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kHistoryElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    for (Entry *entry in self.entries) {
        [ret.children addObject:[entry generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

@end
