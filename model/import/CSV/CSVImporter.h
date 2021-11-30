//
//  CSVImporter.h
//  MacBox
//
//  Created by Strongbox on 21/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHCSVParser.h"
#import "Node.h"

NS_ASSUME_NONNULL_BEGIN

@interface CSVImporter : NSObject

+ (Node*_Nullable)importFromUrl:(NSURL*)url error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
