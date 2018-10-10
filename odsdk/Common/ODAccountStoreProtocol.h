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

@class ODAccountSession;

#import <Foundation/Foundation.h>

/**
 `ODAccountSession` is a protocol to store account information on disk/keychain.
 */
@protocol ODAccountStore <NSObject>

/**
 Loads the account that is currently in use.
 @return The current account that is in use.
 */
- (ODAccountSession *)loadCurrentAccount;

/**
 Loads all known accounts.
 @return An array of ODAccountSessions.
 */
- (NSArray *)loadAccounts;

/**
 Stores the account.
 @param account The account to store.
 @warning This does not set the current account.
 @see storeCurrentAccount:
 */
- (void)storeAccount:(ODAccountSession *)account;

/**
 Stores the account as the current account in use.
 @param account The account to store as the current account in use.
 */
- (void)storeCurrentAccount:(ODAccountSession *)account;

/**
 Deletes the account from the store.
 @param account The account to remove from the store.
 */
- (void)deleteAccount:(ODAccountSession *)account;

@end
