//
//  DeletedObjects.m
//  Strongbox
//
//  Created by Strongbox on 18/05/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "DeletedObjects.h"
#import "KeePassConstants.h"

@implementation DeletedObjects

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kDeletedObjectsElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext*)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.deletedObjects = [NSMutableArray array];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kDeletedObjectElementName]) {
        return [[DeletedObject alloc] initWithXmlElementName:kDeletedObjectElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kDeletedObjectElementName]) {
        [self.deletedObjects addObject:(DeletedObject*)completedObject];
        return YES;
    }
    
    return NO;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if (self.deletedObjects.count == 0 && self.unmanagedChildren.count == 0) {
        return YES;
    }
    
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }
    
    for (DeletedObject *deletedObject in self.deletedObjects) {
        [deletedObject writeXml:serializer];
    }
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    return YES;
}


@end
