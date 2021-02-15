//
//  KeePassFile.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "KeePassFile.h"
#import "KeePassDatabase.h"

@implementation KeePassFile

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kKeePassFileElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _root = [[Root alloc] initWithDefaultsAndInstantiatedChildren:context];
        _meta = [[Meta alloc] initWithDefaultsAndInstantiatedChildren:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kMetaElementName]) {
        return [[Meta alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kRootElementName]) {
        return [[Root alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kMetaElementName]) {
        _meta = (Meta*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kRootElementName]) {
        _root = (Root*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }
    
    if(self.meta) {
        if(![self.meta writeXml:serializer]) {
            return NO;
        }
    }
    
    if(self.root) {
        if (![self.root writeXml:serializer]) {
            return NO;
        }
    }

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }

    [serializer endElement];

    return YES;
}

@end
