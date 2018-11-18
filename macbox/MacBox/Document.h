//
//  Document.h
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AbstractDatabaseFormatAdaptor.h"

@interface Document : NSDocument

@property (nonatomic) BOOL dirty;
@property DatabaseFormat format;

@end

