//
//  RootXmlDomainObject.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "RootXmlDomainObject.h"
#import "KeePassFile.h"
#import "KeePassDatabase.h"

@implementation RootXmlDomainObject

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:@"Dummy" context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _keePassFile = [[KeePassFile alloc] initWithDefaultsAndInstantiatedChildren:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kKeePassFileElementName]) {
        return [[KeePassFile alloc] initWithXmlElementName:kKeePassFileElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kKeePassFileElementName]) {
        _keePassFile = (KeePassFile*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(self.keePassFile) {
        if ( ![self.keePassFile writeXml:serializer] ) {
            return NO;
        }
    }
    
    return [super writeUnmanagedChildren:serializer];
}

@end
