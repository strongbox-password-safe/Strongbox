//
//  ClipboardManager.m
//  Strongbox
//
//  Created by Mark on 10/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ClipboardManager.h"
#import <Cocoa/Cocoa.h>
#import "Settings.h"

@implementation ClipboardManager

+ (instancetype)sharedInstance {
    static ClipboardManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ClipboardManager alloc] init];
    });
    return sharedInstance;
}

- (void)copyNoneConcealedString:(NSString *)string {
    [NSPasteboard.generalPasteboard clearContents]; 
    
    [NSPasteboard.generalPasteboard setString:(string ? string : @"") forType:NSPasteboardTypeString];
}

- (void)copyConcealedString:(NSString *)string {
    [NSPasteboard.generalPasteboard clearContents]; 
    
    if (!Settings.sharedInstance.clipboardHandoff) {
        [NSPasteboard.generalPasteboard prepareForNewContentsWithOptions:NSPasteboardContentsCurrentHostOnly];
    }
    
    if ( Settings.sharedInstance.concealClipboardFromMonitors ) {
        [NSPasteboard.generalPasteboard setString:@"" forType:@"org.nspasteboard.ConcealedType"];
    }
    
    [NSPasteboard.generalPasteboard setString:(string ? string : @"") forType:NSPasteboardTypeString];
}

@end

