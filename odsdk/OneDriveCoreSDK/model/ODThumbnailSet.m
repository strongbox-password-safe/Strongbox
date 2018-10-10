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



#import "ODModels.h"
#import "ODCollection.h"

@interface ODObject()

@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end


@interface ODThumbnailSet()
{
    ODThumbnail *_large;
    ODThumbnail *_medium;
    ODThumbnail *_small;
    ODThumbnail *_source;
}
@end

@implementation ODThumbnailSet	

- (NSString *)id
{
    return self.dictionary[@"id"];
}

- (void)setId:(NSString *)id
{
    self.dictionary[@"id"] = id;
}

- (ODThumbnail *)large
{
    if (!_large){
        _large = [[ODThumbnail alloc] initWithDictionary:self.dictionary[@"large"]];
        if (_large){
            self.dictionary[@"large"] = _large;
        }
    }
    return _large;
}

- (void)setLarge:(ODThumbnail *)large
{
    _large = large;
    self.dictionary[@"large"] = large; 
}

- (ODThumbnail *)medium
{
    if (!_medium){
        _medium = [[ODThumbnail alloc] initWithDictionary:self.dictionary[@"medium"]];
        if (_medium){
            self.dictionary[@"medium"] = _medium;
        }
    }
    return _medium;
}

- (void)setMedium:(ODThumbnail *)medium
{
    _medium = medium;
    self.dictionary[@"medium"] = medium; 
}

- (ODThumbnail *)small
{
    if (!_small){
        _small = [[ODThumbnail alloc] initWithDictionary:self.dictionary[@"small"]];
        if (_small){
            self.dictionary[@"small"] = _small;
        }
    }
    return _small;
}

- (void)setSmall:(ODThumbnail *)small
{
    _small = small;
    self.dictionary[@"small"] = small; 
}

- (ODThumbnail *)source
{
    if (!_source){
        _source = [[ODThumbnail alloc] initWithDictionary:self.dictionary[@"source"]];
        if (_source){
            self.dictionary[@"source"] = _source;
        }
    }
    return _source;
}

- (void)setSource:(ODThumbnail *)source
{
    _source = source;
    self.dictionary[@"source"] = source; 
}

@end
