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

#import "ODAppConfiguration.h"

/**
 ## Default Configuration
 
 The shared app configuration uses the following provided:
 
  1.  ODServiceInfoProvider as the serviceInfoProvider to discover the correct Authentication Provider to use
  2.  ODURLSessionManager as the httpProvider
  3.  ODAccountStore as the persistent accountStore
  4.  ODLogger as the logger for the client (with Error Log level)
  5.  The root view controller of the application as the parentAuthController

 @see ODServiceInfoProvider
 @see ODURLSessionManager
 @see ODAccountStore
 @see ODLogger
 
  All of these values are settable via [ODAppConfiguration defaultConfiguration].`<propName>` = provider;
 */

@interface ODAppConfiguration (DefaultConfiguration)

/**
    Gets the default configuration for the app.
 */
+ (instancetype)defaultConfiguration;

@end
