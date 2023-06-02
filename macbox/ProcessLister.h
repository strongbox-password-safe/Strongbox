//
//  ProcessLister.h
//  MacBox
//
//  Created by Strongbox on 25/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProcessSummary : NSObject

@property pid_t processID;
@property NSString *processName;

@end

@interface ProcessLister : NSObject

+ (NSArray<ProcessSummary*>*)getBSDProcessList;

@end

NS_ASSUME_NONNULL_END
