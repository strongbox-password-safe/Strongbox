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

- (int)id {
    NSString* identifier = [self.nonCustomisedXmlTree.node.xmlAttributes objectForKey:kBinaryIdAttribute];
    return [identifier intValue];
}

- (BOOL)compressed {
    NSString* compressed = [self.nonCustomisedXmlTree.node.xmlAttributes objectForKey:kBinaryCompressedAttribute];

    return [compressed isEqualToString:kAttributeValueTrue];
}

- (NSData *)data {
    NSString *text = self.nonCustomisedXmlTree.node.xmlText;
    NSData* raw = [[NSData alloc] initWithBase64EncodedString:text options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if(self.compressed) {
        raw = [raw gunzippedData];
    }
    
    return raw;
}

- (void)setData:(NSData *)data {
    if(self.compressed) {
        data = [data gzippedData];
    }
    
    NSString *b64 = [data base64EncodedStringWithOptions:kNilOptions];
    self.nonCustomisedXmlTree.node.xmlText = b64;
}

-(void)setCompressed:(BOOL)compressed {
    if(compressed) {
        [self.nonCustomisedXmlTree.node.xmlAttributes setObject:kAttributeValueTrue forKey:kBinaryCompressedAttribute];
    }
    else {
        [self.nonCustomisedXmlTree.node.xmlAttributes removeObjectForKey:kBinaryCompressedAttribute];
    }
}

- (void)setId:(int)id {
    NSString* str = [NSString stringWithFormat:@"%d", id];
    [self.nonCustomisedXmlTree.node.xmlAttributes setObject:str forKey:kBinaryIdAttribute];
}

@end
