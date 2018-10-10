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

@interface ODQuota()
{
}
@end

@implementation ODQuota	


- (int64_t)deleted
{
    
    if (self.dictionary[@"deleted"]){
        return [self.dictionary[@"deleted"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setDeleted:(int64_t)deleted
{
    self.dictionary[@"deleted"] = @(deleted);
}


- (int64_t)remaining
{
    
    if (self.dictionary[@"remaining"]){
        return [self.dictionary[@"remaining"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setRemaining:(int64_t)remaining
{
    self.dictionary[@"remaining"] = @(remaining);
}

- (NSString *)state
{
    return self.dictionary[@"state"];
}

- (void)setState:(NSString *)state
{
    self.dictionary[@"state"] = state;
}


- (int64_t)total
{
    
    if (self.dictionary[@"total"]){
        return [self.dictionary[@"total"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setTotal:(int64_t)total
{
    self.dictionary[@"total"] = @(total);
}


- (int64_t)used
{
    
    if (self.dictionary[@"used"]){
        return [self.dictionary[@"used"] longLongValue];
    }
    //default value if it doesn't exists
    return [@(0) longLongValue];
}

- (void)setUsed:(int64_t)used
{
    self.dictionary[@"used"] = @(used);
}

@end
