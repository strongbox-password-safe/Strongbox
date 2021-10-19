/***************************************************************************
 *
 * XMLWriter: An XML stream writer for iOS.
 * This file is part of the XSWI library - https://skjolber.github.io/xswi
 *
 * Copyright (C) 2010 by Thomas Rørvik Skjølberg
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ****************************************************************************/

#import "XMLWriter.h"
#import "NSString+Extensions.h"

#define NSBOOL(_X_) ((_X_) ? (id)kCFBooleanTrue : (id)kCFBooleanFalse)

@interface XMLWriter (UtilityMethods)


- (void) popNamespaceStack;

- (void) pushNamespaceStack;


- (void) pushElementStack:(NSString*)namespaceURI localName:(NSString*)localName;

- (void) popElementStack;


- (void) writeCloseElement:(BOOL)empty;

- (void) writeNamespaceToStream:(NSString*)prefix namespaceURI:(NSString*)namespaceURI;

- (void) writeEscapeCharacters:(const UniChar*)characters length:(NSUInteger)length;
@end


static NSString *const EMPTY_STRING = @"";
static NSString *const XML_NAMESPACE_URI = @"http:
static NSString *const XML_NAMESPACE_URI_PREFIX = @"xml";
static NSString *const XMLNS_NAMESPACE_URI = @"http:
static NSString *const XMLNS_NAMESPACE_URI_PREFIX = @"xmlns";
static NSString *const XSI_NAMESPACE_URI = @"http:
static NSString *const XSI_NAMESPACE_URI_PREFIX = @"xsi";

@implementation XMLWriter

@synthesize automaticEmptyElements, indentation, lineBreak, level;

- (XMLWriter*) init {
	self = [super init];
	if (self != nil) {
		
		writer = [[NSMutableString alloc] init];
		level = 0;
		openElement = NO;
		emptyElement = NO;
        
		elementLocalNames = [[NSMutableArray alloc]init];
		elementNamespaceURIs = [[NSMutableArray alloc]init];
        
		namespaceURIs = [[NSMutableArray alloc]init];
		namespaceCounts = [[NSMutableArray alloc]init];
		namespaceWritten = [[NSMutableArray alloc]init];
		
		namespaceURIPrefixMap = [[NSMutableDictionary alloc] init];
		prefixNamespaceURIMap = [[NSMutableDictionary alloc] init];
		
		
		automaticEmptyElements = YES;
		
		
		[namespaceCounts addObject:[NSNumber numberWithInt:2]];
		[self setPrefix:XML_NAMESPACE_URI_PREFIX namespaceURI:XML_NAMESPACE_URI];
		[self setPrefix:XMLNS_NAMESPACE_URI_PREFIX namespaceURI:XMLNS_NAMESPACE_URI];
	}
	return self;
}

- (void) pushNamespaceStack {
	
	NSNumber* previousCount = [namespaceCounts lastObject];
	if([namespaceURIs count] == [previousCount unsignedIntegerValue]) {
		
		[namespaceCounts addObject:previousCount];
	} else {
		
		NSNumber* count = [NSNumber numberWithInt:(int)[namespaceURIs count]];
        
		[namespaceCounts addObject:count];
	}
}

- (void) writeNamespaceAttributes {
	if(openElement) {
		
		NSNumber* previousCount = [namespaceCounts lastObject];
		for(NSUInteger i = [previousCount unsignedIntegerValue]; i < [namespaceURIs count]; i++) {
			
			
			id written = [namespaceWritten objectAtIndex:i];
			if(written == NSBOOL(NO)) {
				
				NSString* namespaceURI = [namespaceURIs objectAtIndex:i];
				NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
				
				[self writeNamespaceToStream:prefix namespaceURI:namespaceURI];
				
				[namespaceWritten replaceObjectAtIndex:i withObject:NSBOOL(YES)];
			} else {
				
			}
		}
	} else {
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
	}
}

- (void) popNamespaceStack {
	
	if([namespaceCounts lastObject] != [namespaceCounts objectAtIndex:([namespaceCounts count] - 2)]) {
		
		NSNumber* previousCount = [namespaceCounts lastObject];
		NSNumber* currentCount = [namespaceCounts objectAtIndex:([namespaceCounts count] - 2)];
		for(NSUInteger i = [previousCount unsignedIntegerValue] - 1; i >= [currentCount unsignedIntegerValue]; i--) {
			NSString* removedNamespaceURI = [namespaceURIs objectAtIndex:i];
			NSString* removedPrefix = [namespaceURIPrefixMap objectForKey:removedNamespaceURI];
			
			[prefixNamespaceURIMap removeObjectForKey:removedPrefix];
			[namespaceURIPrefixMap removeObjectForKey:removedNamespaceURI];
			
			[namespaceURIs removeLastObject];
			
			[namespaceWritten removeLastObject];
		}
	} else {
		
	}
	[namespaceCounts removeLastObject];
}

- (void)setPrefix:(NSString*)prefix namespaceURI:(NSString *)namespaceURI {
	if(!namespaceURI) {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Namespace cannot be NULL" userInfo:NULL]);
	}
	if(!prefix) {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Prefix cannot be NULL" userInfo:NULL]);
	}
	if([namespaceURIPrefixMap objectForKey:namespaceURI]) {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Name namespace %@ has already been set", namespaceURI] userInfo:NULL]);
	}
	if([prefixNamespaceURIMap objectForKey:prefix]) {
		
		if([prefix length]) {
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Prefix %@ has already been set", prefix] userInfo:NULL]);
		} else {
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Default namespace has already been set" userInfo:NULL]);
		}
	}
	
	
	[namespaceURIs addObject:namespaceURI];
	[namespaceURIPrefixMap setObject:prefix forKey:namespaceURI];
	[prefixNamespaceURIMap setObject:namespaceURI forKey:prefix];
	
	if(openElement) { 
		[self writeNamespaceToStream:prefix namespaceURI:namespaceURI];
		
		[namespaceWritten addObject:NSBOOL(YES)];
	} else {
		
		[namespaceWritten addObject:NSBOOL(NO)];
	}
}

- (NSString*)getPrefix:(NSString*)namespaceURI {
	return [namespaceURIPrefixMap objectForKey:namespaceURI];
}

- (void) pushElementStack:(NSString*)namespaceURI localName:(NSString*)localName {
	
	[elementLocalNames addObject:localName];
	if(namespaceURI) {
		[elementNamespaceURIs addObject:namespaceURI];
	} else {
		[elementNamespaceURIs addObject:EMPTY_STRING];
	}
}

- (void) popElementStack {
	
	[elementNamespaceURIs removeLastObject];
	[elementLocalNames removeLastObject];
}

- (void) writeStartDocument {
	[self writeStartDocumentWithEncodingAndVersion:NULL version:NULL];
}

- (void) writeStartDocumentWithVersion:(NSString*)version {
	[self writeStartDocumentWithEncodingAndVersion:NULL version:version];
}

- (void) writeStartDocumentWithEncodingAndVersion:(NSString*)aEncoding version:(NSString*)version {
	if([writer length] != 0) {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Document has already been started" userInfo:NULL]);
	} else {
		[self write:@"<?xml version=\""];
		if(version) {
			[self write:version];
		} else {
			
			[self write:@"1.0"];
		}
		[self write:@"\""];
		
		if(aEncoding) {
			[self write:@" encoding=\""];
			[self write:aEncoding];
			[self write:@"\""];
			
			encoding = aEncoding;
		}
		[self write:@" ?>"];
		
	}
}

- (void) writeEndDocument {
	while (level > 0) {
		[self writeEndElement];
	}
}

- (void) writeStartElement:(NSString *)localName {
	[self writeStartElementWithNamespace:NULL localName:localName];
}

- (void) writeCloseStartElement {
	if(openElement) {
		[self writeCloseElement:NO];
	} else {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
	}
}

- (void) writeCloseElement:(BOOL)empty {
	[self writeNamespaceAttributes];
	[self pushNamespaceStack];
	
	if(empty) {
		[self write:@" />"];
	} else {
		[self write:@">"];
	}
	
	openElement = NO;
}

- (void) writeEndElement:(NSString *)localName {
	[self writeEndElementWithNamespace:NULL localName:localName];
}

- (void) writeEndElement {
	if(openElement && automaticEmptyElements) {
		
		[self writeCloseElement:YES]; 
		
		[self popNamespaceStack];
		[self popElementStack];
		
		emptyElement = YES;
		openElement = NO;
		
		level -= 1;
	} else {
		NSString* namespaceURI = [elementNamespaceURIs lastObject];
		NSString* localName = [elementLocalNames lastObject];
		
		if(namespaceURI == EMPTY_STRING) {
			[self writeEndElementWithNamespace:NULL localName:localName];
		} else {
			[self writeEndElementWithNamespace:namespaceURI localName:localName];
		}
	}
}

- (void) writeStartElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	
	[self writeLinebreak];
	[self writeIndentation];
	
	[self write:@"<"];
	if(namespaceURI) {
		NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
		
		if(!prefix) {
			
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
		}
		
		if([prefix length]) {
			[self write:prefix];
			[self write:@":"];
		}
	}
	[self write:localName];
	
	[self pushElementStack:namespaceURI localName:localName];
	
	openElement = YES;
	emptyElement = YES;
	level += 1;
	
}

- (void) writeEndElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
	if(level <= 0) {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"Cannot write more end elements than start elements." userInfo:NULL]);
	}
	
	level -= 1;
	
	if(openElement) {
		
		[self writeCloseElement:NO];
	} else {
		if(emptyElement) {
			
			[self writeLinebreak];
			[self writeIndentation];
		} else {
			
		}
	}
	
	
	[self write:@"</"];
	
	if(namespaceURI) {
		NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
		
		if(!prefix) {
			
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
		}
		
		if([prefix length]) {
			[self write:prefix];
			[self write:@":"];
		}
	}
	
	[self write:localName];
	[self write:@">"];
	
	[self popNamespaceStack];
	[self popElementStack];
	
	emptyElement = YES;
	openElement = NO;
}

- (void) writeEmptyElement:(NSString *)localName {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	
	[self writeLinebreak];
	[self writeIndentation];
	
	[self write:@"<"];
	[self write:localName];
	[self write:@" />"];
	
	emptyElement = YES;
	openElement = NO;
}

- (void) writeEmptyElementWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	
	[self writeLinebreak];
	[self writeIndentation];
	
	[self write:@"<"];
	
	if(namespaceURI) {
		NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
		
		if(!prefix) {
			
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
		}
		
		if([prefix length]) {
			[self write:prefix];
			[self write:@":"];
		}
	}
	
	[self write:localName];
	[self write:@" />"];
	
	emptyElement = YES;
	openElement = NO;
}

- (void) writeAttribute:(NSString *)localName value:(NSString *)value {
	[self writeAttributeWithNamespace:NULL localName:localName value:value];
}

- (void) writeAttributeWithNamespace:(NSString *)namespaceURI localName:(NSString *)localName value:(NSString *)value {
	if(openElement) {
		[self write:@" "];
		
		if(namespaceURI) {
			NSString* prefix = [namespaceURIPrefixMap objectForKey:namespaceURI];
			if(!prefix) {
				
				@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Unknown namespace URI %@", namespaceURI] userInfo:NULL]);
			}
			
			if([prefix length]) {
				[self write:prefix];
				[self write:@":"];
			}
		}
		[self write:localName];
		[self write:@"=\""];
		[self writeEscape:value];
		[self write:@"\""];
	} else {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
	}
}

- (void)setDefaultNamespace:(NSString*)namespaceURI {
	[self setPrefix:EMPTY_STRING namespaceURI:namespaceURI];
}

- (void) writeNamespace:(NSString*)prefix namespaceURI:(NSString *)namespaceURI {
	if(openElement) {
		[self setPrefix:prefix namespaceURI:namespaceURI];
	} else {
		
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
	}
}

- (void) writeDefaultNamespace:(NSString*)namespaceURI {
	[self writeNamespace:EMPTY_STRING namespaceURI:namespaceURI];
}

- (NSString*)getNamespaceURI:(NSString*)prefix {
	return [prefixNamespaceURIMap objectForKey:prefix];
}

-(void) writeNamespaceToStream:(NSString*)prefix namespaceURI:(NSString*)namespaceURI {
	if(openElement) { 
		[self write:@" "];
        
		NSString* xmlnsPrefix = [self getPrefix:XMLNS_NAMESPACE_URI];
		if(!xmlnsPrefix) {
			
			@throw([NSException exceptionWithName:@"XMLWriterException" reason:[NSString stringWithFormat:@"Cannot declare namespace without namespace %@", XMLNS_NAMESPACE_URI] userInfo:NULL]);
		}
		
		[self write:xmlnsPrefix]; 
		if([prefix length]) {
			
            
			[self write:@":"]; 
			[self write:prefix]; 
		} else {
			
		}
		[self write:@"=\""];
		[self writeEscape:namespaceURI];
		[self write:@"\""];
	} else {
		@throw([NSException exceptionWithName:@"XMLWriterException" reason:@"No open start element" userInfo:NULL]);
	}
}

- (void) writeCharacters:(NSString*)text {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	
	[self writeEscape:text];
	
	emptyElement = NO;
}

- (void) writeComment:(NSString*)comment {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	[self write:@"<!--"];
	[self write:comment]; 
	[self write:@"-->"];
	
	emptyElement = NO;
}

- (void) writeProcessingInstruction:(NSString*)target data:(NSString*)data {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	[self write:@"<![CDATA["];
	[self write:target]; 
	[self write:@" "];
	[self write:data]; 
	[self write:@"]]>"];
	
	emptyElement = NO;
}

- (void) writeCData:(NSString*)cdata {
	if(openElement) {
		[self writeCloseElement:NO];
	}
	[self write:@"<![CDATA["];
	[self write:cdata]; 
	[self write:@"]]>"];
	
	emptyElement = NO;
}

- (void) write:(NSString*)value {
	[writer appendString:value];
}

- (void) writeEscape:(NSString*)value {
    if ( value.length == 0 ){
        return;
    }
        
    const UniChar *characters = CFStringGetCharactersPtr((CFStringRef)value); 
    if (characters) {
        [self writeEscapeCharacters:characters length:[value length]];
    }
    else {
        const NSInteger bufferSize = 1024;
        const NSInteger length = value.length;
        
        unichar buffer[bufferSize];
        NSInteger bufferLoops = (length - 1) / bufferSize + 1;
        
        
        
            
        for (int i = 0; i < bufferLoops; i++) {
            NSInteger bufferOffset = i * bufferSize;
            NSInteger charsInBuffer = MIN(length - bufferOffset, bufferSize);
            [value getCharacters:buffer range:NSMakeRange(bufferOffset, charsInBuffer)];

            [self writeEscapeCharacters:buffer length:charsInBuffer];
        }
    }
}

- (void)writeEscapeCharacters:(const UniChar*)characters length:(NSUInteger)length { 
	NSUInteger rangeStart = 0;
	CFIndex rangeLength = 0;
	
	for(NSUInteger i = 0; i < length; i++) {
		
		UniChar c = characters[i];
		if (c <= 0xd7ff)  {
			if (c >= 0x20) {
				switch (c) {
					case 34: {
						
						if(rangeLength) {
							[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
						}
						[self write:@"&quot;"];
                        
						break;
					}
                        
                    case 39: {
                        
                        if(rangeLength) {
                            [self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
                        }
                        [self write:@"&#39;"];
                        
                        break;
                    }
                        
					case 38: {
						
						if(rangeLength) {
							[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
						}
						[self write:@"&amp;"];
						
						break;
					}
						
					case 60: {
						
						if(rangeLength) {
							[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
						}
						
						[self write:@"&lt;"];
						
						break;
					}
						
					case 62: {
						
						if(rangeLength) {
							[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
						}
						
						[self write:@"&gt;"];
						
						break;
					}
						
					default: {
						
						rangeLength++;
						continue;
					}
				}
				
				
				rangeLength = 0;
				rangeStart = i + 1;
				
			} else {
				if (c == '\n' || c == '\r' || c == '\t') {
					
					rangeLength++;
					
					continue;
				} else {
					
				}
			}
		} else if (c <= 0xFFFD) {
			
			rangeLength++;
			
			continue;
		} else {
			
		}
		
		
		if(rangeLength) {
			[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
		}
		
		
		rangeLength = 0;
		rangeStart = i + 1;
	}
	
	
	if(rangeLength) {
		
		[self appendUnicodeCharactersToOutput:characters + rangeStart length:rangeLength];
	}
}

- (void)appendUnicodeCharactersToOutput:(const UniChar*)characters length:(NSUInteger)length {
    @autoreleasepool {
        [self write:[NSString stringWithCharacters:characters length:length]];
    }
}

- (void)writeLinebreak {
	if(lineBreak) {
		[self write:lineBreak];
	}
}

- (void)writeIndentation {
	if(indentation) {
		for (int i = 0; i < level; i++ ) {
			[self write:indentation];
		}
	}
}

- (void) flush {
	
}

- (void) close {
	
}

- (NSMutableString*) toString {
	return writer;
}

- (NSData*) toData {
	if(encoding) {
		return [writer dataUsingEncoding: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding)) allowLossyConversion:NO];
	} else {
		return [writer dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
	}
}

- (void) setPrettyPrinting:(NSString*)aIndentation withLineBreak:(NSString*)aLineBreak {
    self.indentation = aIndentation;
    self.lineBreak = aLineBreak;
}

- (NSError *)streamError {
    return nil;
}

@end
