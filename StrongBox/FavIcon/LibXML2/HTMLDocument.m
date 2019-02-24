//
// FavIcon
// Copyright © 2016 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "HTMLDocument.h"
#import "libxml/tree.h"
#import "libxml/HTMLparser.h"
#import "libxml/xpath.h"
#import "libxml/xpathInternals.h"

NS_ASSUME_NONNULL_BEGIN

@interface HTMLElement ()

- (instancetype)initWithDocument:(HTMLDocument *)document node:(htmlNodePtr)node NS_DESIGNATED_INITIALIZER;

@property (readwrite, nonatomic, nullable) HTMLDocument *document;

@end

@implementation HTMLElement {
  htmlNodePtr _htmlNode;
  NSString *_name;
  NSDictionary *_attributes;
  NSArray *_children;
  NSString * _contents;
}

- (instancetype)initWithDocument:(HTMLDocument *)document node:(htmlNodePtr)node {
  if (self = [super init]) {
    self.document = document;
    _htmlNode = node;
  }
  return self;
}

- (NSString *)name {
  if (!_name) {
    _name = [NSString stringWithUTF8String:(const char *)_htmlNode->name];
  }
  return _name;
}

- (nullable NSString *) contents {
  if (!_contents) {
    char *nodeContent = (char *)_htmlNode->content;
    if (nodeContent) {
      _contents = [NSString stringWithUTF8String:nodeContent];
      xmlFree(nodeContent);
    }
  }
  return _contents;
}

- (NSDictionary<NSString *,NSString *> *)attributes {
  if (!_attributes) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    
    struct _xmlAttr *currentAttr = _htmlNode->properties;
    while (currentAttr) {
      NSString *name = [[NSString stringWithUTF8String:(const char *)currentAttr->name] lowercaseString];
      char *nodeContent = (char *)xmlNodeGetContent(currentAttr->children);
      NSString *value = @"";
      if (nodeContent) {
        value = [NSString stringWithUTF8String:nodeContent];
        xmlFree(nodeContent);
      }
      [attributes setObject:value forKey:name];
      currentAttr = currentAttr->next;
    }
    
    _attributes = attributes;
  }
  return _attributes;
}

- (NSArray<HTMLElement *> *)children {
  if (!_children) {
    NSMutableArray *children = [NSMutableArray array];
    
    xmlNodePtr currentChild = _htmlNode->children;
    while (currentChild) {
      if (currentChild->type == XML_ELEMENT_NODE) {
        [children addObject:[[HTMLElement alloc] initWithDocument:_document node:currentChild]];
      }
      currentChild = currentChild->next;
    }
    
    _children = children;
  }
  return _children;
}

- (void)dealloc {
  self.document = nil; // OK for htmlDocPtr to go away now.
  _htmlNode = nil;
}

@end

@implementation HTMLDocument {
  htmlDocPtr _htmlDocument;
  NSArray *_children;
}

- (instancetype)initWithData:(NSData *)data {
  if (self = [super init]) {
    _htmlDocument = htmlReadMemory(
                                   data.bytes,
                                   (int)data.length,
                                   "",
                                   NULL,
                                   HTML_PARSE_NOWARNING | HTML_PARSE_NOERROR);
  }
  return self;
}

- (void)dealloc {
  if (_htmlDocument) {
    xmlFreeDoc(_htmlDocument);
  }
}

- (instancetype)initWithString:(NSString *)string {
  self = [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
  return self;
}

- (NSArray<HTMLElement *> *)children {
  if (!_children) {
    NSMutableArray *children = [NSMutableArray array];
    
    xmlNodePtr currentChild = _htmlDocument->children;
    while (currentChild) {
      if (currentChild->type == XML_ELEMENT_NODE) {
        [children addObject:[[HTMLElement alloc] initWithDocument:self node:currentChild]];
      }
      currentChild = currentChild->next;
    }
    
    _children = children;
  }
  
  return _children;
}

- (NSArray<HTMLElement *> *)query:(NSString *)xpath {
  NSMutableArray *results = [NSMutableArray array];
  
  xmlXPathContextPtr context = xmlXPathNewContext(_htmlDocument);
  if (!context) {
    return results;
  }
  
  xmlXPathObjectPtr object = xmlXPathEvalExpression((const xmlChar *)[xpath UTF8String], context);
  if (!object) {
    xmlXPathFreeContext(context);
    return results;
  }
  
  if (!object->nodesetval) {
    xmlXPathFreeObject(object);
    xmlXPathFreeContext(context);
    return results;
  }
  
  for (int i = 0; i < object->nodesetval->nodeNr; i++) {
    xmlNodePtr node = object->nodesetval->nodeTab[i];
    [results addObject:[[HTMLElement alloc] initWithDocument:self node:node]];
  }
  
  xmlXPathFreeObject(object);
  xmlXPathFreeContext(context);
  
  return results;
}

@end

NS_ASSUME_NONNULL_END

