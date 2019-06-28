//
//  Times.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Times.h"
#import "KeePassDatabase.h"

// <Times>
//    <LastModificationTime>2018-10-17T19:28:42Z</LastModificationTime>
//    <CreationTime>2018-10-17T19:28:42Z</CreationTime>
//    <LastAccessTime>2018-10-17T19:28:42Z</LastAccessTime>
//    <ExpiryTime>4001-01-01T00:00:00Z</ExpiryTime>
//    <Expires>False</Expires>
//    <UsageCount>0</UsageCount>
//    <LocationChanged>2018-10-17T19:28:42Z</LocationChanged>
// </Times>

@implementation Times

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kTimesElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kTimesElementName context:context]) {
        self.lastAccessTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastAccessTimeElementName context:context];
        self.lastModificationTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastModificationTimeElementName context:context];
        self.creationTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kCreationTimeElementName context:context];
        self.expiryTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kExpiryTimeElementName context:context];
        self.expires = [[GenericTextBooleanElementHandler alloc] initWithXmlElementName:kExpiresElementName context:context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kLastModificationTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastModificationTimeElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kCreationTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kCreationTimeElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kLastAccessTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastAccessTimeElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kExpiryTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kExpiryTimeElementName context:self.context];
    }
    else if([xmlElementName isEqualToString:kExpiresElementName]) {
        return [[GenericTextBooleanElementHandler alloc] initWithXmlElementName:kExpiresElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kLastModificationTimeElementName]) {
        self.lastModificationTime = (GenericTextDateElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCreationTimeElementName]) {
        self.creationTime = (GenericTextDateElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kLastAccessTimeElementName]) {
        self.lastAccessTime = (GenericTextDateElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kExpiryTimeElementName]) {
        self.expiryTime = (GenericTextDateElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kExpiresElementName]) {
        self.expires = (GenericTextBooleanElementHandler*)completedObject;
        return YES;
    }
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kTimesElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.lastModificationTime generateXmlTree]];
    [ret.children addObject:[self.creationTime generateXmlTree]];
    [ret.children addObject:[self.lastAccessTime generateXmlTree]];
    
    if(self.expiryTime.date) {
        [ret.children addObject:[self.expiryTime generateXmlTree]];
    }
    if(self.expires.booleanValue) {
        [ret.children addObject:[self.expires generateXmlTree]];
    }
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"LastModificationTime = [%@], CreationTime = [%@], LastAccessTime = [%@], expires=[%@], expiryTime=[%@]",
            self.lastModificationTime, self.creationTime, self.lastAccessTime, self.expires, self.expiryTime];
}


@end
