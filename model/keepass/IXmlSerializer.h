//
//  IXmlSerializer.h
//  Strongbox
//
//  Created by Mark on 01/09/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#ifndef IXmlSerializer_h
#define IXmlSerializer_h

#import <Foundation/Foundation.h>
#import "XMLWriter.h"
#import "SBLog.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IXmlSerializer <NSObject>

@property (nonatomic, readonly, nullable) NSData* protectedStreamKey;
@property (nonatomic, readonly) NSString* xml;

- (void)beginDocument;
- (void)endDocument;

- (BOOL)beginElement:(NSString*)elementName;
- (BOOL)beginElement:(NSString*)elementName text:(NSString*)text attributes:(NSDictionary*_Nullable)attributes;

- (BOOL)writeElement:(NSString*)elementName text:(NSString*)text;
- (BOOL)writeElement:(NSString*)elementName integer:(NSInteger)integer;
- (BOOL)writeElement:(NSString*)elementName boolean:(BOOL)boolean;
- (BOOL)writeElement:(NSString*)elementName uuid:(NSUUID*)uuid;
- (BOOL)writeElement:(NSString*)elementName date:(NSDate*)date;
- (BOOL)writeElement:(NSString*)elementName text:(NSString*)text protected:(BOOL)protected trimWhitespace:(BOOL)trimWhitespace;
- (BOOL)writeElement:(NSString*)elementName text:(NSString*)text attributes:(NSDictionary*_Nullable)attributes;
- (BOOL)writeElement:(NSString*)elementName text:(NSString*)text attributes:(NSDictionary*_Nullable)attributes trimWhitespace:(BOOL)trimWhitespace;

- (void)endElement;

@property (readonly, nullable) NSError* streamError;

@end

NS_ASSUME_NONNULL_END

#endif /* IXmlSerializer_h */
