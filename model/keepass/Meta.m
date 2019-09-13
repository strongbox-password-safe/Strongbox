//
//  Meta.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "Meta.h"
#import "KeePassDatabase.h"
#import "NSUUID+Zero.h"
#import "SimpleXmlValueExtractor.h"

@implementation Meta

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kMetaElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        self.generator = kStrongboxGenerator;
        
        self.historyMaxItems = @(kDefaultHistoryMaxItems);
        self.historyMaxSize = @(kDefaultHistoryMaxSize);
        self.recycleBinEnabled = YES;
        _recycleBinChanged = [NSDate date];
        _recycleBinGroup = NSUUID.zero;
    }
    
    return self;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if ([xmlElementName isEqualToString:kV3BinariesListElementName]) {
        return [[V3BinariesList alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kCustomIconListElementName]) {
        return [[CustomIconList alloc] initWithContext:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGeneratorElementName]) {
        self.generator = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kHeaderHashElementName]) {
        self.headerHash = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kV3BinariesListElementName]) {
        self.v3binaries = (V3BinariesList*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kCustomIconListElementName]) {
        self.customIconList = (CustomIconList*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kHistoryMaxItemsElementName]) {
        self.historyMaxItems = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kHistoryMaxSizeElementName]) {
        self.historyMaxSize = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinEnabledElementName]) {
        self.recycleBinEnabled = [SimpleXmlValueExtractor getBool:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinGroupElementName]) {
        self.recycleBinGroup = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinChangedElementName]) {
        self.recycleBinChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
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
    
    if(self.generator && ![serializer writeElement:kGeneratorElementName text:self.generator]) return NO;
    if(self.headerHash && ![serializer writeElement:kHeaderHashElementName text:self.headerHash]) return NO;
    if(self.historyMaxItems && ![serializer writeElement:kHistoryMaxItemsElementName integer:self.historyMaxItems.integerValue]) return NO;
    if(self.historyMaxSize && ![serializer writeElement:kHistoryMaxSizeElementName integer:self.historyMaxSize.integerValue]) return NO;
    if(![serializer writeElement:kRecycleBinEnabledElementName boolean:self.recycleBinEnabled]) return NO;
    if(self.recycleBinGroup && ![serializer writeElement:kRecycleBinGroupElementName uuid:self.recycleBinGroup]) return NO;
    if(self.recycleBinChanged  && ![serializer writeElement:kRecycleBinChangedElementName date:self.recycleBinChanged]) return NO;
    if(self.v3binaries && ![self.v3binaries writeXml:serializer]) return NO;
    
    if(self.customIconList && ![self.customIconList writeXml:serializer]) return NO;

    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Generator = [%@]\nHeader Hash=[%@]\nV3 Binaries = [%@], historyMaxItems = [%@], historyMaxSize = [%@], Recycle Bin enabled = [%d], Recycle Bin Group = [%@], Recycle Bin Changed = [%@]",
            self.generator, self.headerHash, self.v3binaries, self.historyMaxItems, self.historyMaxSize, self.recycleBinEnabled, self.recycleBinGroup, self.recycleBinChanged];
}

@end
