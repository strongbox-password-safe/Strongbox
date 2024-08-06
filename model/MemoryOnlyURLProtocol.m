//
//  MemoryOnlyURLProtocol.m
//  Strongbox
//
//  Created by Strongbox on 04/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import "MemoryOnlyURLProtocol.h"
#import <UIKit/UIKit.h>

@implementation MemoryOnlyURLProtocol

+ (NSString*) memoryOnlyURLProtocolScheme {
    return @"strongbox-memory-only";
}

+ (void) registerMemoryOnlyURLProtocol {
    static BOOL inited = NO;
    
    if ( ! inited ) {
        [NSURLProtocol registerClass:[MemoryOnlyURLProtocol class]];
        inited = YES;
    }
}



+ (BOOL)canInitWithRequest:(NSURLRequest *)theRequest {
    slog(@"%@ received %@ with url='%@' and scheme='%@'",
            self, NSStringFromSelector(_cmd),
            [[theRequest URL] absoluteString], [[theRequest URL] scheme]);

    NSString *theScheme = [[theRequest URL] scheme];

    return ([theScheme caseInsensitiveCompare: [MemoryOnlyURLProtocol memoryOnlyURLProtocolScheme]] == NSOrderedSame );
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    slog(@"%@ received %@", self, NSStringFromSelector(_cmd));

    return request;
}

- (void)startLoading {
    slog(@"%@ received %@ - start", self, NSStringFromSelector(_cmd));

    NSURLRequest *request = [self request];

    NSString* theString = @"Mark is Cool!";

    NSDictionary* fontAttrs =
            [NSDictionary dictionaryWithObjectsAndKeys:
                UIColor.redColor, NSForegroundColorAttributeName,
                [UIFont systemFontOfSize:36], NSFontAttributeName,
                nil];

    /* calculate the size of the rendered string */
    CGSize tsz = [theString sizeWithAttributes:fontAttrs];

    UIGraphicsBeginImageContext(tsz);
    
    [theString drawAtPoint:CGPointMake(0,0) withAttributes:fontAttrs];

    UIImage* myImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    NSData *data = UIImageJPEGRepresentation(myImage, .75);
    
    NSURLResponse *response =
        [[NSURLResponse alloc] initWithURL:[request URL]
            MIMEType:@"image/jpeg"
            expectedContentLength:-1
            textEncodingName:nil];

    id<NSURLProtocolClient> client = [self client];

    [client URLProtocol:self didReceiveResponse:response
            cacheStoragePolicy:NSURLCacheStorageNotAllowed];

    [client URLProtocol:self didLoadData:data];

    [client URLProtocolDidFinishLoading:self];

    slog(@"%@ received %@ - end", self, NSStringFromSelector(_cmd));
}

- (void)stopLoading {
    slog(@"%@ received %@", self, NSStringFromSelector(_cmd));
}

@end
