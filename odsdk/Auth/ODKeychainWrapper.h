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


@class ODAccountSession, ODServiceInfo;

#import <Foundation/Foundation.h>

/**
 This class is used to store account sessions in the keychain.
 Warning: If this class is a subclass that is used with ODAccountStore, make sure to overload all three methods.
 */
@interface ODKeychainWrapper : NSObject

/**
 Adds or updates a given account in the keychain.
 @param account The account to store in the keychain.
 */
- (void)addOrUpdateAccount:(ODAccountSession *)account;

/**
 Retrieves an account with the given accountId.
 @param accountId The accountId to use as the key for the account.
 @param serviceInfo The service info used to create the ODAccountSession.
 @return A complete ODAccountSession object.
 */
- (ODAccountSession *)readFromKeychainWithAccountId:(NSString *)accountId serviceInfo:(ODServiceInfo *)serviceInfo;

/**
 Removes an accountSession from the keychain.
 @param account The account to remove from the keychain.
 */
- (void)removeAccountFormKeychain:(ODAccountSession *)account;


@end
