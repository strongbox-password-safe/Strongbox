//
//  MainWindow.m
//  MacBox
//
//  Created by Strongbox on 23/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "MainWindow.h"

@implementation MainWindow

// With thanks to PAULO ANDRADE!
// https://stackoverflow.com/questions/23494436/how-to-disable-nsdocuments-window-title-popup/23500601#23500601

+ (NSButton *)standardWindowButton:(NSWindowButton)b forStyleMask:(NSWindowStyleMask)styleMask {
    if ( b == NSWindowDocumentVersionsButton ) { 
        return nil;
    }
    
    return [super standardWindowButton:b forStyleMask:styleMask];
}

@end
