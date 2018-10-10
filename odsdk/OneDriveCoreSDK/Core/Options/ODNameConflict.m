//  Copyright 2015 Microsoft Corporation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


#import "ODNameConflict.h"

static NSString *const conflictBehaviorKey = @"@name.conflictBehavior";
static NSString *const failBehavior = @"fail";
static NSString *const replaceBehavior = @"replace";
static NSString *const renameBehavior = @"rename";

@implementation ODNameConflict

+ (instancetype)fail
{
    return [ODNameConflict conflictBehaviorWithValue:[failBehavior copy]];
}

+ (instancetype)replace
{
    return [ODNameConflict conflictBehaviorWithValue:[replaceBehavior copy]];
}

+ (instancetype)rename
{
    return [ODNameConflict conflictBehaviorWithValue:[renameBehavior copy]];
}
           
+ (instancetype)conflictBehaviorWithValue:(NSString *)value
{
    return [[ODNameConflict alloc] initWithKey:[conflictBehaviorKey copy] value:value];
}
           
@end
