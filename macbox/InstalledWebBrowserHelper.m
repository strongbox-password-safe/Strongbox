//
//  InstalledWebBrowserHelper.m
//  Strongbox
//
//  Created by Mark on 16/04/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "InstalledWebBrowserHelper.h"

@implementation InstalledWebBrowserHelper

// TODO: Some Day...

// https://stackoverflow.com/questions/17227348/nsstring-to-cfstringref-and-cfstringref-to-nsstring-in-arc
// https://stackoverflow.com/questions/12166532/get-icon-for-another-application-in-objective-c
// https://stackoverflow.com/questions/44778078/get-macos-default-browser-name-lscopydefaultapplicationurlforcontenttype

//        NSArray* apps = (NSArray*)CFBridgingRelease(LSCopyAllHandlersForURLScheme(CFSTR("https"))) ;
//        NSLog(@"Browsers: %@", apps);
//        NSString* defaultBundleId = (__bridge NSString*)LSCopyDefaultHandlerForURLScheme(CFSTR("https"));
//        NSLog(@"default is %@", defaultBundleId);
//
////        NSString* first = [apps firstObject];
//        NSArray* urls = (NSArray*)CFBridgingRelease(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)defaultBundleId, nil));
//        NSLog(@"URLS: %@", urls);
//
//        NSBundle* bundle = [NSBundle bundleWithURL:urls.firstObject];
//        NSLog(@"Bundle: %@", bundle.localizedInfoDictionary);// [bundle objectForInfoDictionaryKey:@"CFBundleName"]);



@end
