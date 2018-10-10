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

@interface ODObject()

@property (strong, nonatomic) NSMutableDictionary *dictionary;

@end

@interface ODShared()
{
    ODCollection *_effectiveRoles;
    ODIdentitySet *_owner;
}
@end

@implementation ODShared	

- (ODIdentitySet *)owner
{
    if (!_owner){
        _owner = [[ODIdentitySet alloc] initWithDictionary:self.dictionary[@"owner"]];
        if (_owner){
            self.dictionary[@"owner"] = _owner;
        }
    }
    return _owner;
}

- (void)setOwner:(ODIdentitySet *)owner
{
    _owner = owner;
    self.dictionary[@"owner"] = owner; 
}

- (NSString *)scope
{
    return self.dictionary[@"scope"];
}

- (void)setScope:(NSString *)scope
{
    self.dictionary[@"scope"] = scope;
}

@end
