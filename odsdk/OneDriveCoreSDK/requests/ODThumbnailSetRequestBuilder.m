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

@implementation ODThumbnailSetRequestBuilder

-(ODThumbnailRequestBuilder *)large
{
    return [[ODThumbnailRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"large"] client:self.client];

}

-(ODThumbnailRequestBuilder *)medium
{
    return [[ODThumbnailRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"medium"] client:self.client];

}

-(ODThumbnailRequestBuilder *)small
{
    return [[ODThumbnailRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"small"] client:self.client];

}

-(ODThumbnailRequestBuilder *)source
{
    return [[ODThumbnailRequestBuilder alloc] initWithURL:[self.requestURL URLByAppendingPathComponent:@"source"] client:self.client];

}


- (ODThumbnailSetRequest *)request
{
    return [self requestWithOptions:nil];
}

- (ODThumbnailSetRequest *) requestWithOptions:(NSArray *)options
{
    return [[ODThumbnailSetRequest alloc] initWithURL:self.requestURL options:options client:self.client];
}

@end
