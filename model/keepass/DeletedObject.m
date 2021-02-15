//
//  DeletedObject.m
//  MacBox
//
//  Created by Strongbox on 14/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DeletedObject.h"
#import "KeePassDatabase.h"
#import "SimpleXmlValueExtractor.h"

@implementation DeletedObject

// <DeletedObject>
//     <UUID>OjDGBkygSXyeOh33r/aDJQ==</UUID>



- (instancetype)initWithContext:(XmlProcessingContext *)context {
    return [self initWithXmlElementName:kDeletedObjectElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext *)context {
    if(self = [super initWithXmlElementName:kDeletedObjectElementName context:context]) {
        self.uuid = NSUUID.UUID;
        self.deletionTime = NSDate.date;
    }
    
    return self;
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kUuidElementName]) {
        self.uuid = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kDeletionTimeElementName]) {
        self.deletionTime = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }

    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(!self.uuid || !self.deletionTime) {
        return YES;
    }

    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    if(![serializer writeElement:kDeletionTimeElementName date:self.deletionTime]) return NO;
    if(![serializer writeElement:kUuidElementName uuid:self.uuid]) return NO;
        
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@] deleted [%@]", self.uuid, self.deletionTime];
}

@end
