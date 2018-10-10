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


@interface ODPermission()
{
    ODIdentitySet *_grantedTo;
    ODSharingInvitation *_invitation;
    ODItemReference *_inheritedFrom;
    ODSharingLink *_link;
    ODCollection *_roles;
}
@end

@implementation ODPermission	

- (ODIdentitySet *)grantedTo
{
    if (!_grantedTo){
        _grantedTo = [[ODIdentitySet alloc] initWithDictionary:self.dictionary[@"grantedTo"]];
        if (_grantedTo){
            self.dictionary[@"grantedTo"] = _grantedTo;
        }
    }
    return _grantedTo;
}

- (void)setGrantedTo:(ODIdentitySet *)grantedTo
{
    _grantedTo = grantedTo;
    self.dictionary[@"grantedTo"] = grantedTo; 
}

- (NSString *)id
{
    return self.dictionary[@"id"];
}

- (void)setId:(NSString *)id
{
    self.dictionary[@"id"] = id;
}

- (ODSharingInvitation *)invitation
{
    if (!_invitation){
        _invitation = [[ODSharingInvitation alloc] initWithDictionary:self.dictionary[@"invitation"]];
        if (_invitation){
            self.dictionary[@"invitation"] = _invitation;
        }
    }
    return _invitation;
}

- (void)setInvitation:(ODSharingInvitation *)invitation
{
    _invitation = invitation;
    self.dictionary[@"invitation"] = invitation; 
}

- (ODItemReference *)inheritedFrom
{
    if (!_inheritedFrom){
        _inheritedFrom = [[ODItemReference alloc] initWithDictionary:self.dictionary[@"inheritedFrom"]];
        if (_inheritedFrom){
            self.dictionary[@"inheritedFrom"] = _inheritedFrom;
        }
    }
    return _inheritedFrom;
}

- (void)setInheritedFrom:(ODItemReference *)inheritedFrom
{
    _inheritedFrom = inheritedFrom;
    self.dictionary[@"inheritedFrom"] = inheritedFrom; 
}

- (ODSharingLink *)link
{
    if (!_link){
        _link = [[ODSharingLink alloc] initWithDictionary:self.dictionary[@"link"]];
        if (_link){
            self.dictionary[@"link"] = _link;
        }
    }
    return _link;
}

- (void)setLink:(ODSharingLink *)link
{
    _link = link;
    self.dictionary[@"link"] = link; 
}

- (NSString *)shareId
{
    return self.dictionary[@"shareId"];
}

- (void)setShareId:(NSString *)shareId
{
    self.dictionary[@"shareId"] = shareId;
}

@end
