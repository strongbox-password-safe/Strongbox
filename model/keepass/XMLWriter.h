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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol XMLStreamWriter

- (void) writeStartDocument;
- (void) writeStartDocumentWithVersion:(NSString*)version;
- (void) writeStartDocumentWithEncodingAndVersion:(NSString*_Nullable)encoding version:(NSString*_Nullable)version;

- (void) writeStartElement:(NSString *)localName;

- (void) writeEndElement; 
- (void) writeEndElement:(NSString *)localName;

- (void) writeEmptyElement:(NSString *)localName;

- (void) writeEndDocument; 

- (void) writeAttribute:(NSString *)localName value:(NSString *)value;

- (void) writeCharacters:(NSString*)text;
- (void) writeComment:(NSString*)comment;
- (void) writeProcessingInstruction:(NSString*)target data:(NSString*)data;
- (void) writeCData:(NSString*)cdata;


- (NSMutableString*) toString;

- (NSData*) toData;


- (void) flush;

- (void) close;

- (void) setPrettyPrinting:(NSString*)indentation withLineBreak:(NSString*)lineBreak;

@end


@protocol NSXMLStreamWriter <XMLStreamWriter>

- (void) writeStartElementWithNamespace:(NSString *_Nullable)namespaceURI localName:(NSString *)localName;
- (void) writeEndElementWithNamespace:(NSString *_Nullable)namespaceURI localName:(NSString *)localName;
- (void) writeEmptyElementWithNamespace:(NSString *_Nullable)namespaceURI localName:(NSString *)localName;

- (void) writeAttributeWithNamespace:(NSString *_Nullable)namespaceURI localName:(NSString *)localName value:(NSString *)value;


- (void)setPrefix:(NSString*)prefix namespaceURI:(NSString *)namespaceURI;

- (void) writeNamespace:(NSString*)prefix namespaceURI:(NSString *)namespaceURI;


- (void)setDefaultNamespace:(NSString*)namespaceURI;

- (void) writeDefaultNamespace:(NSString*)namespaceURI;

- (NSString*)getPrefix:(NSString*)namespaceURI;
- (NSString*)getNamespaceURI:(NSString*)prefix;


@property (readonly, nullable) NSError* streamError;

@end

@interface XMLWriter : NSObject <NSXMLStreamWriter> {
		
	
	NSMutableString* writer;
	
	
	NSString* encoding;
	
	
	int level;
	
	BOOL openElement;
	
	BOOL emptyElement;
	
	
	NSMutableArray* elementLocalNames;
	NSMutableArray* elementNamespaceURIs;
	
	
	NSMutableArray* namespaceURIs;
	
	NSMutableArray* namespaceCounts;
	
	NSMutableArray* namespaceWritten;

	
	NSMutableDictionary* namespaceURIPrefixMap;
	NSMutableDictionary* prefixNamespaceURIMap;

	
	NSString* indentation;
	
	NSString* lineBreak;
	
	
	BOOL automaticEmptyElements;
}

@property (nonatomic, retain, readwrite) NSString* indentation;
@property (nonatomic, retain, readwrite) NSString* lineBreak;
@property (nonatomic, assign, readwrite) BOOL automaticEmptyElements;
@property (nonatomic, readonly) int level;



- (void) writeLinebreak;

- (void) writeIndentation;

- (void) writeCloseStartElement;


- (void) writeNamespaceAttributes;

- (void) writeEscape:(NSString*)value;

- (void) write:(NSString*)value;

@end

NS_ASSUME_NONNULL_END
