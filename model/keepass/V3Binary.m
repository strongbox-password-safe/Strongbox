//
//  V3Binary.m
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "V3Binary.h"
#import "KeePassConstants.h"
#import "NSData+GZIP.h"

@implementation V3Binary

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [super initWithXmlElementName:kBinaryElementName context:context];
}

- (void)onCompleted {
    NSString* identifier = self.originalAttributes[kBinaryIdAttribute];
    self.id = identifier.intValue;
    
    NSString* compressed = self.originalAttributes[kBinaryCompressedAttribute];
    self.compressed = [compressed isEqualToString:kAttributeValueTrue];

    NSString *text = self.originalText;
    NSData* raw = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(self.compressed) {
        raw = [raw gunzippedData];
    }
    
    self.data = raw;
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    // There is possible a protected flag on this, so we need to merge with original attributes
    self.data = self.data ? self.data : [NSData data];
    NSString *b64 = [(self.compressed ? [self.data gzippedData] : self.data) base64EncodedStringWithOptions:kNilOptions];
    
    NSMutableDictionary* attributes = self.originalAttributes ? self.originalAttributes.mutableCopy : @{}.mutableCopy;
    attributes[kBinaryIdAttribute] = @(self.id).stringValue;
    if(self.compressed) {
        attributes[kBinaryCompressedAttribute] = kAttributeValueTrue;
    }
    else {
        [attributes removeObjectForKey:kBinaryCompressedAttribute];
    }
    
    return [serializer writeElement:self.originalElementName text:b64 attributes:attributes];
}

@end
