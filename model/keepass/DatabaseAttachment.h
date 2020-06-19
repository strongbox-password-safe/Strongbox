//
//  Attachment.h
//  Strongbox
//
//  Created by Mark on 01/11/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DatabaseAttachment : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData*)data compressed:(BOOL)compressed protectedInMemory:(BOOL)protectedInMemory; // TODO: Retire
- (instancetype)initWithStream:(NSInputStream*)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory;
- (instancetype)initWithStream:(NSInputStream *)stream length:(NSUInteger)length protectedInMemory:(BOOL)protectedInMemory compressed:(BOOL)compressed NS_DESIGNATED_INITIALIZER;

- (void)cleanup;

@property (readonly) NSUInteger estimatedStorageBytes;
@property (readonly) NSUInteger length;
@property (readonly) BOOL compressed; // Keepass v3
@property (readonly) BOOL protectedInMemory; // Keepass v4
@property (readonly) NSString* digestHash; // Use native hash/equals 

@property (readonly, nonnull) NSData* deprecatedData; // TODO: Replace with Stream

@end

NS_ASSUME_NONNULL_END
