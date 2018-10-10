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

@interface ODSharingLink()
{
    ODIdentity *_application;
}
@end

@implementation ODSharingLink	

- (ODIdentity *)application
{
    if (!_application){
        _application = [[ODIdentity alloc] initWithDictionary:self.dictionary[@"application"]];
        if (_application){
            self.dictionary[@"application"] = _application;
        }
    }
    return _application;
}

- (void)setApplication:(ODIdentity *)application
{
    _application = application;
    self.dictionary[@"application"] = application; 
}

- (NSString *)type
{
    return self.dictionary[@"type"];
}

- (void)setType:(NSString *)type
{
    self.dictionary[@"type"] = type;
}

- (NSString *)webUrl
{
    return self.dictionary[@"webUrl"];
}

- (void)setWebUrl:(NSString *)webUrl
{
    self.dictionary[@"webUrl"] = webUrl;
}

- (NSString *)webHtml
{
    return self.dictionary[@"webHtml"];
}

- (void)setWebHtml:(NSString *)webHtml
{
    self.dictionary[@"webHtml"] = webHtml;
}

- (NSString *)configuratorUrl
{
    return self.dictionary[@"configuratorUrl"];
}

- (void)setConfiguratorUrl:(NSString *)configuratorUrl
{
    self.dictionary[@"configuratorUrl"] = configuratorUrl;
}

@end
