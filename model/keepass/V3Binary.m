//
//  V3Binary.m
//  Strongbox
//
//  Created by Mark on 02/11/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "V3Binary.h"
#import "KeePassConstants.h"
#import "NSData+GZIP.h"
#import "NSData+Extensions.h"

@interface V3Binary ()

@end

@implementation V3Binary

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kBinaryElementName context:context];
}

- (instancetype)initWithContext:(XmlProcessingContext *)context dbAttachment:(DatabaseAttachment *)dbAttachment {
    if( self = [super initWithXmlElementName:kBinaryElementName context:context] ) {
        self.dbAttachment = dbAttachment;
        self.compressed = dbAttachment.compressed;
    }
    
    return self;
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext *)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.dbAttachment = [[DatabaseAttachment alloc] initForStreamWriting:YES compressed:YES];
    }
    
    return self;
}

- (BOOL)handlesStreamingText {
    return YES;
}

- (BOOL)appendStreamedText:(NSString *)text {
    NSInteger ret = [self.dbAttachment writeStreamWithB64Text:text];
    
    return ret >= 0;
}

- (void)onCompleted {
    NSString* identifier = self.originalAttributes[kBinaryIdAttribute];
    self.id = identifier.intValue;
    
    NSString* compressed = self.originalAttributes[kBinaryCompressedAttribute];
    self.compressed = [compressed isEqualToString:kAttributeValueTrue];

    [self.dbAttachment closeWriteStream];
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    
    NSMutableDictionary* attributes = self.originalAttributes ? self.originalAttributes.mutableCopy : @{}.mutableCopy;
    attributes[kBinaryIdAttribute] = @(self.id).stringValue;
    if(self.compressed) {
        attributes[kBinaryCompressedAttribute] = kAttributeValueTrue;
    }
    else {
        [attributes removeObjectForKey:kBinaryCompressedAttribute];
    }
    
    NSInputStream* inputStream = [self.dbAttachment getPlainTextInputStream];
    if ( !inputStream ) {
        NSLog(@"WARNWARN: Could not serialize V3Binary! Could not read attachment PT stream.");
        return NO;
    }

    
    NSData* data = [NSData dataWithContentsOfStream:inputStream];

    if (!data) {
        NSLog(@"Could not serialize V3Binary!");
        return NO;
    }

    NSData* maybeCompressed = (self.compressed ? [data gzippedData] : data);

    NSString *b64 = [maybeCompressed base64EncodedStringWithOptions:kNilOptions];

    return [serializer writeElement:self.originalElementName text:b64 attributes:attributes];
}


@end
