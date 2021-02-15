//
//  Times.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Times.h"
#import "KeePassDatabase.h"
#import "SimpleXmlValueExtractor.h"

// <Times>
//    <LastModificationTime>2018-10-17T19:28:42Z</LastModificationTime>
//    <CreationTime>2018-10-17T19:28:42Z</CreationTime>
//    <LastAccessTime>2018-10-17T19:28:42Z</LastAccessTime>






@implementation Times

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kTimesElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:kTimesElementName context:context]) {
        self.lastAccessTime = NSDate.date;
        self.lastModificationTime = NSDate.date;
        self.creationTime = NSDate.date;
        self.expiryTime = nil;
        self.expires = NO;
        self.usageCount = nil;
        self.locationChangedTime = nil;
    }
    
    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kLastModificationTimeElementName]) {
        self.lastModificationTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCreationTimeElementName]) {
        self.creationTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kLastAccessTimeElementName]) {
        self.lastAccessTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kExpiryTimeElementName]) {
        self.expiryTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kExpiresElementName]) {
        self.expires = [SimpleXmlValueExtractor getBool:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kUsageCountElementName]) {
        self.usageCount = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kLocationChangedTimeElementName]) {
        self.locationChangedTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }

    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    if(self.lastModificationTime && ![serializer writeElement:kLastModificationTimeElementName date:self.lastModificationTime]) return NO;
    if(self.creationTime && ![serializer writeElement:kCreationTimeElementName date:self.creationTime]) return NO;
    if(self.lastAccessTime && ![serializer writeElement:kLastAccessTimeElementName date:self.lastAccessTime]) return NO;
    if(self.expiryTime && ![serializer writeElement:kExpiryTimeElementName date:self.expiryTime]) return NO;
    if(![serializer writeElement:kExpiresElementName boolean:self.expires]) return NO;
    if(self.usageCount && ![serializer writeElement:kUsageCountElementName integer:self.usageCount.integerValue]) return NO;
    if(self.locationChangedTime && ![serializer writeElement:kLocationChangedTimeElementName date:self.locationChangedTime]) return NO;
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (BOOL)isEqual:(id)object {
    if (object == nil) {
        return NO;
    }
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[Times class]]) {
        return NO;
    }
    
    Times* other = (Times*)object;
    
    if(![self.lastModificationTime isEqualToDate:other.lastModificationTime]) {
        return NO;
    }
    if(![self.creationTime isEqualToDate:other.creationTime]) {
        return NO;
    }
    if(![self.lastAccessTime isEqualToDate:other.lastAccessTime]) {
        return NO;
    }
    if(self.expires && ![self.expiryTime isEqualToDate:other.expiryTime]) {
        return NO;
    }
    if(![self.locationChangedTime isEqualToDate:other.locationChangedTime]) {
        return NO;
    }
    if(![self.usageCount isEqual:other.usageCount]) {
        return NO;
    }
    if(self.expires != other.expires) {
        return NO;
    }

    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"LastModificationTime = [%@], CreationTime = [%@], LastAccessTime = [%@], expires=[%d], expiryTime=[%@], usageCount = [%@], locationChanged = [%@]",
            self.lastModificationTime, self.creationTime, self.lastAccessTime, self.expires, self.expiryTime, self.usageCount, self.locationChangedTime];
}

@end
