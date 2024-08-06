//
//  RootHandler.m
//  Strongbox
//
//  Created by Mark on 17/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "BaseXmlDomainObjectHandler.h"
#import "KeePassConstants.h"

@interface BaseXmlDomainObjectHandler ()

@property (nonatomic) NSString* internalElementName;
@property (nonatomic) NSDictionary *internalAttributes;
@property (nonatomic) NSString* internalText;

@property (nonatomic) NSMutableArray<id<XmlParsingDomainObject>>* lazyUnmanagedChildElements;

@end

@implementation BaseXmlDomainObjectHandler

- (instancetype)init {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];

    return nil;
}

- (instancetype)initWithXmlElementName:(NSString*)xmlElementName context:(nonnull XmlProcessingContext *)context {
    if(self = [super init]) {
        if(!context) {
            slog(@"Parsing Context cannot be nil.");
            [NSException raise:NSInternalInconsistencyException
                        format:@"Parsing Context cannot be nil %@ in a subclass", NSStringFromSelector(_cmd)];
            return nil;
        }
        
        self.internalElementName = xmlElementName;
        self.context = context;
    }

    return self;
}

- (BOOL)isV3BinaryHack {
    return NO;
}

- (BOOL)appendStreamedText:(NSString *)text {
    return NO;
}
    
- (NSString *)originalElementName {
    return self.internalElementName;
}

- (NSDictionary *)originalAttributes {
    return self.internalAttributes;
}

- (NSString *)originalText {
    return self.internalText ? self.internalText : @"";
}

- (void)setXmlInfo:(nonnull NSString *)elementName attributes:(nonnull NSDictionary *)attributes {
    self.internalElementName = elementName;
    self.internalAttributes = attributes;
}

- (void)setXmlText:(nonnull NSString *)text {
    self.internalText = text;
}

- (void)onCompleted { }

- (BOOL)addKnownChildObject:(id<XmlParsingDomainObject>)completedObject withXmlElementName:(nonnull NSString *)withXmlElementName {
    return NO; 
}

- (id<XmlParsingDomainObject>)getChildHandler:(nonnull NSString *)xmlElementName {
    return nil; 
}

- (void)addUnknownChildObject:(id<XmlParsingDomainObject>)xmlItem {
    slog(@"WARNWARN - Found Unknown Element: [%@]", xmlItem.originalElementName);
    
    if(!self.lazyUnmanagedChildElements) {
        self.lazyUnmanagedChildElements = [NSMutableArray arrayWithCapacity:32];
    }
    [self.lazyUnmanagedChildElements addObject:xmlItem];
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    if(![serializer beginElement:self.originalElementName
                            text:self.originalText
                      attributes:self.originalAttributes]) {
        return NO;
    }

    [self writeUnmanagedChildren:serializer];
    
    [serializer endElement];
    
    return YES;
}

- (NSArray<id<XmlParsingDomainObject>>* )unmanagedChildren {
    return self.lazyUnmanagedChildElements;
}

- (BOOL)writeUnmanagedChildren:(id<IXmlSerializer>)serializer {
    if(!self.lazyUnmanagedChildElements || self.lazyUnmanagedChildElements.count == 0) {
        return YES;
    }
    
    for (id<XmlParsingDomainObject> child in self.lazyUnmanagedChildElements) {
        if(![child writeXml:serializer]) {
            return NO;
        }
    }
    
    return YES;
}

@end
