//
//  MacConstants.m
//  MacBox
//
//  Created by Strongbox on 24/11/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

#import "MacConstants.h"

#ifdef DEBUG
NSString* const kDefaultAppGroupName = @"4326J8XDF2.group.strongbox.mac.mcguill"; // Prefixing the Team ID - To get around the constant popup asking to allow Strongbox access it's settings... eventually it would be best to migrate to this as seems to be required by Apple on mac, or Apple just fixes things so it's the same as on iOS, e.g. you don't need the  Team ID as a prefix but that seems like it will never happen. See: https://developer.apple.com/forums/thread/721701
#else
NSString* const kDefaultAppGroupName = @"group.strongbox.mac.mcguill";
#endif

