//
//  DAVListingParser.h
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DAVResponseItem;

@interface DAVListingParser : NSObject < NSXMLParserDelegate > {
  @private
	NSXMLParser *_parser;
	NSMutableString *_currentString;
	NSMutableArray *_items;
	DAVResponseItem *_currentItem;
	BOOL _inResponseType;
}

- (id)initWithData:(NSData *)data;

- (NSArray *)parse:(NSError **)error;

@end
