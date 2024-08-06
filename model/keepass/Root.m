//
//  Root.m
//  Strongbox
//
//  Created by Mark on 20/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "Root.h"
#import "KeePassDatabase.h"

@implementation Root

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kRootElementName context:context];
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext *)context {
    if(self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.deletedObjects = [[DeletedObjects alloc] initWithContext:self.context];
    }
    
    return self;
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        self.rootGroup = [[KeePassGroup alloc] initAsKeePassRoot:context];
        self.deletedObjects = [[DeletedObjects alloc] initWithContext:self.context];
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGroupElementName]) {
        if(self.rootGroup == nil) {
            
            
            
            
            return [[KeePassGroup alloc] initWithContext:self.context];
        }
        else {
            slog(@"WARN: Multiple Root Groups found. Ignoring extra.");
        }
    }
    else if ([xmlElementName isEqualToString:kDeletedObjectsElementName]) {
        return [[DeletedObjects alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGroupElementName] && self.rootGroup == nil) {
        _rootGroup = (KeePassGroup*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kDeletedObjectsElementName]) {
        self.deletedObjects = completedObject;
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

    if (self.rootGroup) {
        @autoreleasepool {
            [self.rootGroup writeXml:serializer];
        }
    }
    
    if (self.deletedObjects) {
        [self.deletedObjects writeXml:serializer];
    }

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

@end
