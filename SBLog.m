//
//  SBLog.m
//  MacBox
//
//  Created by Strongbox on 22/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "SBLog.h"

//#ifndef IS_APP_EXTENSION
//#import "Strongbox-Swift.h"
//#else
//#import "Strongbox_Auto_Fill-Swift.h"
//#endif

void SBLogActual( NSString* fmt, ... ) {
    va_list argptr;
    va_start(argptr,fmt);
    NSLogv(fmt, argptr);
    va_end(argptr);
    

}
