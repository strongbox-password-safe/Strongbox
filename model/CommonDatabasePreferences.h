//
//  CommonDatabasePreferences.h
//  Strongbox
//
//  Created by Strongbox on 05/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#ifndef CommonDatabasePreferences_h
#define CommonDatabasePreferences_h

#if TARGET_OS_IPHONE

#import "DatabasePreferences.h"

typedef DatabasePreferences* METADATA_PTR;
typedef DatabasePreferences CommonDatabasePreferences;

#else

#import "MacDatabasePreferences.h"

typedef MacDatabasePreferences* METADATA_PTR;
typedef MacDatabasePreferences CommonDatabasePreferences;

#endif

#endif /* CommonDatabasePreferences_h */
