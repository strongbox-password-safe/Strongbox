// Copyright (c) 2015 Microsoft Corporation
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// 
// CodeGen: b53160c326682c5d0326144548f8f1a5297b0f62


//////////////////////////////////////////////////////////////////
// This file was generated and any changes will be overwritten. //
//////////////////////////////////////////////////////////////////



#import "ODODataEntities.h"

@implementation ODItemRequestBuilder

- (ODPermissionsCollectionRequestBuilder *)permissions
{
    return [[ODPermissionsCollectionRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"permissions"]  
                                                               client:self.client];
}

- (ODPermissionRequestBuilder *)permissions:(NSString *)permission
{
    return [[self permissions] permission:permission];
}

- (ODVersionsCollectionRequestBuilder *)versions
{
    return [[ODVersionsCollectionRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"versions"]  
                                                            client:self.client];
}

- (ODItemRequestBuilder *)versions:(NSString *)item
{
    return [[self versions] item:item];
}

- (ODChildrenCollectionRequestBuilder *)children
{
    return [[ODChildrenCollectionRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"children"]  
                                                            client:self.client];
}

- (ODItemRequestBuilder *)children:(NSString *)item
{
    return [[self children] item:item];
}

- (ODThumbnailsCollectionRequestBuilder *)thumbnails
{
    return [[ODThumbnailsCollectionRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"thumbnails"]  
                                                              client:self.client];
}

- (ODThumbnailSetRequestBuilder *)thumbnails:(NSString *)thumbnailSet
{
    return [[self thumbnails] thumbnailSet:thumbnailSet];
}


- (ODItemRequest *)request
{
    return [self requestWithOptions:nil];
}

- (ODItemRequest *) requestWithOptions:(NSArray *)options
{
    return [[ODItemRequest alloc] initWithURL:self.requestURL options:options client:self.client];
}

- (ODItemContentRequest *) contentRequestWithOptions:(NSArray *)options
{
    NSURL *contentURL = [self.requestURL URLByAppendingPathComponent:@"content"];
    return [[ODItemContentRequest alloc] initWithURL:contentURL options:options client:self.client];
}

- (ODItemContentRequest *) contentRequest
{
    return [self contentRequestWithOptions:nil];
}

- (ODItemCreateSessionRequestBuilder *)createSessionWithItem:(ODChunkedUploadSessionDescriptor *)item 
{
    NSURL *actionURL = [self.requestURL URLByAppendingPathComponent:@"upload.createSession"];
    return [[ODItemCreateSessionRequestBuilder alloc] initWithItem:item
                                                               URL:actionURL
                                                            client:self.client];


}

- (ODItemCopyRequestBuilder *)copyWithName:(NSString *)name parentReference:(ODItemReference *)parentReference 
{
    NSURL *actionURL = [self.requestURL URLByAppendingPathComponent:@"action.copy"];
    return [[ODItemCopyRequestBuilder alloc] initWithName:name
                                          parentReference:parentReference
                                                      URL:actionURL
                                                   client:self.client];


}

- (ODItemCreateLinkRequestBuilder *)createLinkWithType:(NSString *)type 
{
    NSURL *actionURL = [self.requestURL URLByAppendingPathComponent:@"action.createLink"];
    return [[ODItemCreateLinkRequestBuilder alloc] initWithType:type
                                                            URL:actionURL
                                                         client:self.client];


}

- (ODItemDeltaRequestBuilder *)deltaWithToken:(NSString *)token 
{
    NSURL *actionURL = [self.requestURL URLByAppendingPathComponent:@"view.delta"];
    return [[ODItemDeltaRequestBuilder alloc] initWithToken:token
                                                        URL:actionURL
                                                     client:self.client];


}

- (ODItemSearchRequestBuilder *)searchWithQ:(NSString *)q 
{
    NSURL *actionURL = [self.requestURL URLByAppendingPathComponent:@"view.search"];
    return [[ODItemSearchRequestBuilder alloc] initWithQ:q
                                                     URL:actionURL
                                                  client:self.client];


}

@end
