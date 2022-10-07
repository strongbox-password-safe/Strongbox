//
//  SealedBoxHelper.h
//  MacBox
//
//  Created by Strongbox on 25/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BoxKeyPair;

NS_ASSUME_NONNULL_BEGIN

@interface CryptoBoxHelper : NSObject

+ (BoxKeyPair*)createKeyPair;
+ (NSString*)createNonce;
+ (NSString*_Nullable)seal:(NSString*)message nonce:(NSString*)nonce theirPublicKey:(NSString*)theirPublicKey myPrivateKey:(NSString*)myPrivateKey;
+ (NSString*_Nullable)unSeal:(NSString*)message nonce:(NSString*)nonce theirPublicKey:(NSString*)theirPublicKey myPrivateKey:(NSString*)myPrivateKey;

@end

NS_ASSUME_NONNULL_END
