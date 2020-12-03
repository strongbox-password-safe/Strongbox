//
//  CustomDataItem.m
//  Strongbox
//
//  Created by Strongbox on 02/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "CustomDataItem.h"
#import "KeePassConstants.h"
#import "SimpleXmlValueExtractor.h"

@implementation CustomDataItem

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kCustomDataItemElementName context:context]) {
        self.key = @"";
        self.value = @"";
    }

    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeyElementName]) {
        self.key = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }

    if([withXmlElementName isEqualToString:kValueElementName]) {
        self.value = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    
    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    return NO; 
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{ [%@] = [%@] }", self.key, self.value];
}

@end
