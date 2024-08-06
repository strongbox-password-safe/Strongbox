//
//  PasswordHistoryEntry.h
//
//
//  Created by Mark on 28/05/2017.
//
//

#import <Foundation/Foundation.h>
#import "SBLog.h"

@interface PasswordHistoryEntry : NSObject

@property (nonatomic, retain, readonly) NSDate *timestamp;
@property (nonatomic, retain, readonly) NSString *password;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithTimestamp:(NSDate *)timestamp password:(NSString *)password NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPassword:(NSString *)password;

@end
