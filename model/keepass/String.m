//
//  String.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "String.h"
#import "KeePassDatabase.h"
#import "SimpleXmlValueExtractor.h"

@implementation String

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kStringElementName context:context]) {
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
        StringValue* sv = [SimpleXmlValueExtractor getStringValueFromText:completedObject];
        self.value = sv.value;
        self.protected = sv.protected;
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
