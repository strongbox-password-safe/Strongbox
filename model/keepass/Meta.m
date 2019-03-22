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

@implementation Meta

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kMetaElementName context:context];
}

- (instancetype)initWithDefaultsAndInstantiatedChildren:(XmlProcessingContext*)context {
    self = [self initWithContext:context];
    
    if(self) {
        _generator = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kGeneratorElementName context:context];
        self.generator.text = kStrongboxGenerator;
        
        _historyMaxItems = [[GenericTextIntegerElementHandler alloc] initWithXmlElementName:kHistoryMaxItemsElementName context:context];
        self.historyMaxItems.integer = kDefaultHistoryMaxItems;
        
        _historyMaxSize = [[GenericTextIntegerElementHandler alloc] initWithXmlElementName:kHistoryMaxSizeElementName context:context];
        self.historyMaxSize.integer = kDefaultHistoryMaxSize;
        
        _recycleBinEnabled = [[GenericTextBooleanElementHandler alloc] initWithXmlElementName:kRecycleBinEnabledElementName context:context];
        self.recycleBinEnabled.booleanValue = YES;
        
        _recycleBinChanged = [[GenericTextDateElementHandler alloc] initWithXmlElementName:kRecycleBinChangedElementName context:context];
        _recycleBinChanged.date = [NSDate date];
        
        _recycleBinGroup = [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kRecycleBinGroupElementName context:context];
        _recycleBinGroup.uuid = NSUUID.zero;
    }
    
    return self;
}

- (void)setHash:(NSString*)hash {
    if(!self.headerHash) {
        self.headerHash = [[GenericTextStringElementHandler alloc] initWithXmlElementName:kHeaderHashElementName context:self.context];
    }
    
    self.headerHash.text = hash;
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    if([xmlElementName isEqualToString:kGeneratorElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kGeneratorElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kHeaderHashElementName]) {
        return [[GenericTextStringElementHandler alloc] initWithXmlElementName:kHeaderHashElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kV3BinariesListElementName]) {
        return [[V3BinariesList alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kCustomIconListElementName]) {
        return [[CustomIconList alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kHistoryMaxItemsElementName]) {
        return [[GenericTextIntegerElementHandler alloc] initWithXmlElementName:kHistoryMaxItemsElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kHistoryMaxSizeElementName]) {
        return [[GenericTextIntegerElementHandler alloc] initWithXmlElementName:kHistoryMaxSizeElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kRecycleBinEnabledElementName]) {
        return [[GenericTextBooleanElementHandler alloc] initWithXmlElementName:kRecycleBinEnabledElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kRecycleBinGroupElementName]) {
        return [[GenericTextUuidElementHandler alloc] initWithXmlElementName:kRecycleBinGroupElementName context:self.context];
    }
    else if ([xmlElementName isEqualToString:kRecycleBinChangedElementName]) {
        return [[GenericTextDateElementHandler alloc] initWithXmlElementName:kRecycleBinChangedElementName context:self.context];
    }
    
    return [super getChildHandler:xmlElementName];
}

- (BOOL)addKnownChildObject:(nonnull NSObject *)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    if([withXmlElementName isEqualToString:kGeneratorElementName]) {
        self.generator = (GenericTextStringElementHandler*)completedObject;
        return YES;
    }
    else if([withXmlElementName isEqualToString:kHeaderHashElementName]) {
        self.headerHash = (GenericTextStringElementHandler*)completedObject;
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
        self.historyMaxItems = (GenericTextIntegerElementHandler*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kHistoryMaxSizeElementName]) {
        self.historyMaxSize = (GenericTextIntegerElementHandler*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinEnabledElementName]) {
        self.recycleBinEnabled = (GenericTextBooleanElementHandler*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinGroupElementName]) {
        self.recycleBinGroup = (GenericTextUuidElementHandler*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kRecycleBinChangedElementName]) {
        self.recycleBinChanged = (GenericTextDateElementHandler*)completedObject;
        return YES;
    }
    else {
        return NO;
    }
}

- (XmlTree *)generateXmlTree {
    XmlTree* ret = [[XmlTree alloc] initWithXmlElementName:kMetaElementName];
    
    ret.node = self.nonCustomisedXmlTree.node;
    
    if(self.generator) [ret.children addObject:[self.generator generateXmlTree]];
    if(self.headerHash) [ret.children addObject:[self.headerHash generateXmlTree]];
    if(self.v3binaries) [ret.children addObject:[self.v3binaries generateXmlTree]];
    if(self.customIconList) [ret.children addObject:[self.customIconList generateXmlTree]];
    if(self.historyMaxItems) [ret.children addObject:[self.historyMaxItems generateXmlTree]];
    if(self.historyMaxSize) [ret.children addObject:[self.historyMaxSize generateXmlTree]];
    if(self.recycleBinEnabled) [ret.children addObject:[self.recycleBinEnabled generateXmlTree]];
    if(self.recycleBinGroup) [ret.children addObject:[self.recycleBinGroup generateXmlTree]];
    if(self.recycleBinChanged) [ret.children addObject:[self.recycleBinChanged generateXmlTree]];
    
    [ret.children addObjectsFromArray:self.nonCustomisedXmlTree.children];
    
    return ret;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Generator = [%@]\nHeader Hash=[%@]\nV3 Binaries = [%@], historyMaxItems = [%@], historyMaxSize = [%@], Recycle Bin enabled = [%@], Recycle Bin Group = [%@], Recycle Bin Changed = [%@]",
            self.generator, self.headerHash, self.v3binaries, self.historyMaxItems, self.historyMaxSize, self.recycleBinEnabled, self.recycleBinGroup, self.recycleBinChanged];
}

@end
