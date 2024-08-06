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
#import "SBLog.h"

@interface V3Binary ()

@property BOOL completionDone;

@end

@implementation V3Binary

- (instancetype)initWithContext:(XmlProcessingContext*)context {
    return [self initWithXmlElementName:kBinaryElementName context:context];
}

- (instancetype)initWithContext:(XmlProcessingContext *)context dbAttachment:(KeePassAttachmentAbstractionLayer *)dbAttachment {
    if( self = [super initWithXmlElementName:kBinaryElementName context:context] ) {
        self.dbAttachment = dbAttachment;
        self.compressed = dbAttachment.compressed;
    }
    
    return self;
}

- (instancetype)initWithXmlElementName:(NSString *)xmlElementName context:(XmlProcessingContext *)context {
    if (self = [super initWithXmlElementName:xmlElementName context:context]) {
        self.dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initForStreamWriting:YES compressed:YES];
    }
    
    return self;
}

- (BOOL)isV3BinaryHack {
    return YES;
}

- (BOOL)appendStreamedText:(NSString *)text {
    NSInteger ret = [self.dbAttachment writeStreamWithB64Text:text];
    
    return ret >= 0;
}

- (void)onCompletedWithStrangeProtectedAttribute:(NSData*)data {
    self.completionDone = YES;
    self.dbAttachment = [[KeePassAttachmentAbstractionLayer alloc] initNonPerformantWithData:data compressed:YES protectedInMemory:NO];
}

- (void)onCompleted {
    NSString* identifier = self.originalAttributes[kBinaryIdAttribute];
    self.id = identifier.intValue;
    
    NSString* compressed = self.originalAttributes[kBinaryCompressedAttribute];
    self.compressed = [compressed isEqualToString:kAttributeValueTrue];

    if ( !self.completionDone ) {
        [self.dbAttachment closeWriteStream];
    }
}

- (BOOL)writeXml:(id<IXmlSerializer>)serializer {
    NSMutableDictionary* attributes = @{}.mutableCopy;

    attributes[kBinaryIdAttribute] = @(self.id).stringValue;
    if(self.compressed) {
        attributes[kBinaryCompressedAttribute] = kAttributeValueTrue;
    }
    else {
        [attributes removeObjectForKey:kBinaryCompressedAttribute];
    }
    
    
    NSData* data = self.dbAttachment.nonPerformantFullData;
    
    if (!data) {
        slog(@"Could not serialize V3Binary!");
        return NO;
    }

    NSData* maybeCompressed = (self.compressed ? [data gzippedData] : data);

    NSString *b64 = [maybeCompressed base64EncodedStringWithOptions:kNilOptions];

    return [serializer writeElement:self.originalElementName text:b64 attributes:attributes];
}

@end
