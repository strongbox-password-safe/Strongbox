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


#import <Foundation/Foundation.h>
#import "ODAccountStoreProtocol.h"
#import "ODKeychainWrapper.h"
#import "ODLoggerProtocol.h"

/**
 `ODAccountStore` stores account information on disk and in keychain.
 */
@interface ODAccountStore : NSObject <ODAccountStore>

/**
 The logger to use. May be nil.
 */
@property (strong, nonatomic) id <ODLogger> logger;

/**
 Gets the shared instance of the account store.
 The accounts are stored using the ADAL keychain, and the account ids 
 are stored in the Documents directory.
 */
+ (instancetype)defaultAccountStore;

/**
 Creates an account store with the given file.
 @param filePath The path to the given file, used for the store.
 */
- (instancetype)initWithStoreLocation:(NSString *)filePath;

/**
 Creates an account store with a given file path and a keychain wrapper.
 @param filePath The path to the given file used for the store.
 @param keychainWrapper A keychain wrapper object.
 @param logger The logger to use.
 @see ODKeychainWrapper
 */
- (instancetype)initWithStoreLocation:(NSString *)filePath
                      keychainWrapper:(ODKeychainWrapper *)keychainWrapper
                               logger:(id <ODLogger>)logger;

/**
 Creates an account store with a keychain wrapper.
 @param keychainWrapper A keychain wrapper that conforms to the ODKeychainWrapper protocol.
 @see ODKeychainWrapper
 */
- (instancetype)initWithKeychainWrapper:(ODKeychainWrapper *)keychainWrapper;

@end

