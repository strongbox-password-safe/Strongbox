//
//  Meta.m
//  Strongbox
//
//  Created by Mark on 18/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
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
        
        self.customData = [[CustomData alloc] initWithContext:context];
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
    else if ([xmlElementName isEqualToString:kCustomDataElementName]) {
        return [[CustomData alloc] initWithContext:self.context];
    }
    else if ([xmlElementName isEqualToString:kMemoryProtectionElementName]) {
        return [[MemoryProtection alloc] initWithContext:self.context];
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
    else if ([withXmlElementName isEqualToString:kMemoryProtectionElementName]) {
        self.memoryProtection = (MemoryProtection*)completedObject;
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
    else if([withXmlElementName isEqualToString:kCustomDataElementName]) {
        self.customData = (CustomData*)completedObject;
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kSettingsChangedElementName]) {
        self.settingsChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kDatabaseNameElementName]) {
        self.databaseName = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kDatabaseNameChangedElementName]) {
        self.databaseNameChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kDatabaseDescriptionElementName]) {
        self.databaseDescription = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kDatabaseDescriptionChangedElementName]) {
        self.databaseDescriptionChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kDefaultUserNameElementName]) {
        self.defaultUserName = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kDefaultUserNameChangedElementName]) {
        self.defaultUserNameChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if([withXmlElementName isEqualToString:kColorElementName]) {
        self.color = [SimpleXmlValueExtractor getStringFromText:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kEntryTemplatesGroupElementName]) {
        self.entryTemplatesGroup = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kEntryTemplatesGroupChangedElementName]) {
        self.entryTemplatesGroupChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kMaintenanceHistoryDaysElementName]) {
        self.maintenanceHistoryDays = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kMasterKeyChangedElementName]) {
        self.masterKeyChanged = [SimpleXmlValueExtractor getDate:completedObject v4Format:self.context.v4Format];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kMasterKeyChangeRecElementName]) {
        self.masterKeyChangeRec = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kMasterKeyChangeForceElementName]) {
        self.masterKeyChangeForce = [SimpleXmlValueExtractor getNumber:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kMasterKeyChangeForceOnceElementName]) {
        self.masterKeyChangeForceOnce = [SimpleXmlValueExtractor getOptionalBool:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kLastSelectedGroupElementName]) {
        self.lastSelectedGroup = [SimpleXmlValueExtractor getUuid:completedObject];
        return YES;
    }
    else if ([withXmlElementName isEqualToString:kLastTopVisibleGroupElementName]) {
        self.lastTopVisibleGroup = [SimpleXmlValueExtractor getUuid:completedObject];
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

    if (self.customData && self.customData.dictionary.count) {
        if ( ![self.customData writeXml:serializer] ) return NO;
    }

    if ( self.memoryProtection ) {
        if ( ![self.memoryProtection writeXml:serializer] ) return NO;
    }
    
    if (self.settingsChanged && ![serializer writeElement:kSettingsChangedElementName date:self.settingsChanged]) return NO;
    if (self.databaseName && ![serializer writeElement:kDatabaseNameElementName text:self.databaseName]) return NO;
    if (self.databaseNameChanged && ![serializer writeElement:kDatabaseNameChangedElementName date:self.databaseNameChanged]) return NO;
    if (self.databaseDescription && ![serializer writeElement:kDatabaseDescriptionElementName text:self.databaseDescription]) return NO;
    if (self.databaseDescriptionChanged && ![serializer writeElement:kDatabaseDescriptionChangedElementName date:self.databaseDescriptionChanged]) return NO;
    if (self.defaultUserName && ![serializer writeElement:kDefaultUserNameElementName text:self.defaultUserName]) return NO;
    if (self.defaultUserNameChanged && ![serializer writeElement:kDefaultUserNameChangedElementName date:self.defaultUserNameChanged]) return NO;
    if (self.color && ![serializer writeElement:kColorElementName text:self.color]) return NO;
    if (self.entryTemplatesGroup && ![serializer writeElement:kEntryTemplatesGroupElementName uuid:self.entryTemplatesGroup]) return NO;
    if (self.entryTemplatesGroupChanged && ![serializer writeElement:kEntryTemplatesGroupChangedElementName date:self.entryTemplatesGroupChanged]) return NO;

    if ( self.maintenanceHistoryDays && ![serializer writeElement:kMaintenanceHistoryDaysElementName integer:self.maintenanceHistoryDays.integerValue]) return NO;
    if ( self.masterKeyChanged && ![serializer writeElement:kMasterKeyChangedElementName date:self.masterKeyChanged]) return NO;
    if ( self.masterKeyChangeRec && ![serializer writeElement:kMasterKeyChangeRecElementName integer:self.masterKeyChangeRec.integerValue]) return NO;
    if ( self.masterKeyChangeForce && ![serializer writeElement:kMasterKeyChangeForceElementName integer:self.masterKeyChangeForce.integerValue]) return NO;
    if ( self.masterKeyChangeForceOnce && ![serializer writeElement:kMasterKeyChangeForceOnceElementName boolean:self.masterKeyChangeForceOnce.boolValue]) return NO;
    if ( self.lastSelectedGroup && ![serializer writeElement:kLastSelectedGroupElementName uuid:self.lastSelectedGroup]) return NO;
    if ( self.lastTopVisibleGroup && ![serializer writeElement:kLastTopVisibleGroupElementName uuid:self.lastTopVisibleGroup]) return NO;
    
    
    
    if(![super writeUnmanagedChildren:serializer]) {
        return NO;
    }
    
    [serializer endElement];
    
    return YES;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Generator = [%@]\nHeader Hash=[%@]\nV3 Binaries = [%@], historyMaxItems = [%@], historyMaxSize = [%@], Recycle Bin enabled = [%d], Recycle Bin Group = [%@], Recycle Bin Changed = [%@], customDate = [%@]",
            self.generator, self.headerHash, self.v3binaries, self.historyMaxItems, self.historyMaxSize, self.recycleBinEnabled, self.recycleBinGroup, self.recycleBinChanged, self.customData];
}

@end
