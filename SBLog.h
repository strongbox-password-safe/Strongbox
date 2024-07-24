//
//  SBLog.h
//  MacBox
//
//  Created by Strongbox on 22/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void SBLogActual(NSString* fmt, ... );

#ifdef DEBUG
#define SBLog(...) SBLogActual(__VA_ARGS__)
#else
#define SBLog(...)
#endif

NS_ASSUME_NONNULL_END
