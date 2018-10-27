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

- (instancetype)init {
    return [self initWithXmlElementName:kTimesElementName];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName {
    if(self = [super initWithXmlElementName:kTimesElementName]) {
        self.lastAccessTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastAccessTimeElementName];
        self.lastModificationTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastModificationTimeElementName];
        self.creationTime = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kCreationTimeElementName];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kLastModificationTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastModificationTimeElementName];
    }
    else if([xmlElementName isEqualToString:kCreationTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kCreationTimeElementName];
    }
    else if([xmlElementName isEqualToString:kLastAccessTimeElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kLastAccessTimeElementName];
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
    
    return NO;
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kTimesElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    [ret.children addObject:[self.lastModificationTime generateXmlTree]];
    [ret.children addObject:[self.creationTime generateXmlTree]];
    [ret.children addObject:[self.lastAccessTime generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"LastModificationTime = [%@], CreationTime = [%@], LastAccessTime = [%@]",
            self.lastModificationTime, self.creationTime, self.lastAccessTime];
}


@end
