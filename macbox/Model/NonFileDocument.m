//
//  NonFileDocument.m
//  MacBox
//
//  Created by Strongbox on 17/02/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "NonFileDocument.h"

@implementation NonFileDocument // SFTP / WebDAV and other non File Based

//+ (BOOL)autosavesInPlace {
// //   slog(@"NonFileDocument::autosavesInPlace");
//
//    return YES;


+ (BOOL)preservesVersions {
    return NO;
}


@end
