//
//  DAVListingParser.m
//  DAVKit
//
//  Copyright Matt Rajca 2010. All rights reserved.
//


#import "DAVListingParser.h"

#import "DAVResponseItem.h"
#import "ISO8601DateFormatter.h"
#import "NSDateRFC1123.h"

@interface DAVListingParser ()

- (NSDate *)_ISO8601DateWithString:(NSString *)aString;

@end


@implementation DAVListingParser

- (id)initWithData:(NSData *)data {
	NSParameterAssert(data != nil);
	
	self = [super init];
	if (self) {
		_items = [[NSMutableArray alloc] init];
		
		_parser = [[NSXMLParser alloc] initWithData:data];
		[_parser setDelegate:self];
		[_parser setShouldProcessNamespaces:YES];
	}
	return self;
}

- (NSArray *)parse:(NSError **)error {
	if (![_parser parse]) {
		if (error) {
			*error = [_parser parserError];
		}
		
		return nil;
	}
	
	return [_items copy];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	[_currentString appendString:string];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
	attributes:(NSDictionary *)attributeDict {
	
	_currentString = [[NSMutableString alloc] init];
	
	if ([elementName isEqualToString:@"response"]) {
		_currentItem = [[DAVResponseItem alloc] init];
	}
	else if ([elementName isEqualToString:@"resourcetype"]) {
		_inResponseType = YES;
	}
}

- (NSDate *)_ISO8601DateWithString:(NSString *)aString {
	ISO8601DateFormatter *formatter = [[ISO8601DateFormatter alloc] init];
	
	return [formatter dateFromString:aString];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	
	if ([elementName isEqualToString:@"href"]) {
		_currentItem.href = [_currentString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}
	else if ([elementName isEqualToString:@"getcontentlength"]) {
		_currentItem.contentLength = [_currentString longLongValue];
	}
	else if ([elementName isEqualToString:@"getcontenttype"]) {
		_currentItem.contentType = _currentString;
	}
	else if ([elementName isEqualToString:@"modificationdate"]) {
		_currentItem.modificationDate = [self _ISO8601DateWithString:_currentString];
	}
	else if ([elementName isEqualToString:@"getlastmodified"]) {
		_currentItem.modificationDate = [NSDate dateFromRFC1123:_currentString];
	}
	else if ([elementName isEqualToString:@"creationdate"]) {
		_currentItem.creationDate = [self _ISO8601DateWithString:_currentString];
	}
	else if ([elementName isEqualToString:@"resourcetype"]) {
		_inResponseType = NO;
	}
	else if ([elementName isEqualToString:@"collection"] && _inResponseType) {
		_currentItem.resourceType = DAVResourceTypeCollection;
	}
	else if ([elementName isEqualToString:@"response"]) {
		[_items addObject:_currentItem];
		
		_currentItem = nil;
	}
	
	_currentString = nil;
}

@end
