//
//  CredentialsGetter.h
//  MacBox
//
//  Created by Strongbox on 31/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef CredentialsGetter_h
#define CredentialsGetter_h

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

typedef UIViewController* PARENT_UI_ELEMENT_PTR;

#else

#import <Cocoa/Cocoa.h>

typedef NSViewController* PARENT_UI_ELEMENT_PTR;

#endif


NS_ASSUME_NONNULL_BEGIN

@protocol CredentialsGetter <NSObject>

- (void)foo;

@end

#endif /* CredentialsGetter_h */

NS_ASSUME_NONNULL_END
