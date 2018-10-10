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

@interface ODSharingInvitation()
{
    ODIdentitySet *_invitedBy;
}
@end

@implementation ODSharingInvitation	

- (NSString *)email
{
    return self.dictionary[@"email"];
}

- (void)setEmail:(NSString *)email
{
    self.dictionary[@"email"] = email;
}

- (ODIdentitySet *)invitedBy
{
    if (!_invitedBy){
        _invitedBy = [[ODIdentitySet alloc] initWithDictionary:self.dictionary[@"invitedBy"]];
        if (_invitedBy){
            self.dictionary[@"invitedBy"] = _invitedBy;
        }
    }
    return _invitedBy;
}

- (void)setInvitedBy:(ODIdentitySet *)invitedBy
{
    _invitedBy = invitedBy;
    self.dictionary[@"invitedBy"] = invitedBy; 
}


- (BOOL)signInRequired
{
    
    if (self.dictionary[@"signInRequired"]){
        return [self.dictionary[@"signInRequired"] boolValue];
    }
    //default value if it doesn't exists
    return [@(0) boolValue];
}

- (void)setSignInRequired:(BOOL)signInRequired
{
    self.dictionary[@"signInRequired"] = @(signInRequired);
}

- (NSString *)sendInvitationStatus
{
    return self.dictionary[@"sendInvitationStatus"];
}

- (void)setSendInvitationStatus:(NSString *)sendInvitationStatus
{
    self.dictionary[@"sendInvitationStatus"] = sendInvitationStatus;
}

- (NSString *)inviteErrorResolveUrl
{
    return self.dictionary[@"inviteErrorResolveUrl"];
}

- (void)setInviteErrorResolveUrl:(NSString *)inviteErrorResolveUrl
{
    self.dictionary[@"inviteErrorResolveUrl"] = inviteErrorResolveUrl;
}

@end
