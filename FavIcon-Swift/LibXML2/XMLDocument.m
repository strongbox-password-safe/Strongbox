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

#import "XMLDocument.h"
#import "libxml/tree.h"
#import "libxml/xpath.h"
#import "libxml/xpathInternals.h"

NS_ASSUME_NONNULL_BEGIN

@interface XMLElement ()

@property (readwrite, nonatomic, nullable) LBXMLDocument *document;

- (instancetype)initWithDocument:(LBXMLDocument *)document node:(xmlNodePtr)node NS_DESIGNATED_INITIALIZER;


@end


@implementation XMLElement {
  xmlNodePtr _xmlNode;
  NSString *_name;
  NSDictionary *_attributes;
  NSArray *_children;
}

- (instancetype)initWithDocument:(LBXMLDocument *)document node:(xmlNodePtr)node {
  if (self = [super init]) {
    self.document = document;
    _xmlNode = node;
  }
  return self;
}

- (NSString *)name {
  if (!_name) {
    _name = [NSString stringWithUTF8String:(const char *)_xmlNode->name];
  }
  return _name;
}

- (NSDictionary<NSString *,NSString *> *)attributes {
  if (!_attributes) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    
    struct _xmlAttr *currentAttr = _xmlNode->properties;
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

- (NSArray<XMLElement *> *)children {
  if (!_children) {
    NSMutableArray *children = [NSMutableArray array];
    
    xmlNodePtr currentChild = _xmlNode->children;
    while (currentChild) {
      if (currentChild->type == XML_ELEMENT_NODE) {
        [children addObject:[[XMLElement alloc] initWithDocument:_document node:currentChild]];
      }
      currentChild = currentChild->next;
    }
    
    _children = children;
  }
  return _children;
}

- (void)dealloc {
  self.document = nil; 
  _xmlNode = nil;
}

@end

@implementation LBXMLDocument {
    xmlDocPtr _xmlDocument;
    NSArray *_children;
}

- (instancetype)initWithData:(NSData *)data {
    if (self = [super init]) {
        _xmlDocument = xmlReadMemory(
            data.bytes,
            (int)data.length,
            "",
            NULL,
            0);
    }
    return self;
}

- (void)dealloc {
    if (_xmlDocument) {
        xmlFreeDoc(_xmlDocument);
    }
}

- (instancetype)initWithString:(NSString *)string {
    self = [self initWithData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    return self;
}

- (NSArray<XMLElement *> *)children {
    if (!_children) {
        NSMutableArray *children = [NSMutableArray array];
        
        xmlNodePtr currentChild = _xmlDocument->children;
        while (currentChild) {
            if (currentChild->type == XML_ELEMENT_NODE) {
                [children addObject:[[XMLElement alloc] initWithDocument:self node:currentChild]];
            }
            currentChild = currentChild->next;
        }
        
        _children = children;
    }
    
    return _children;
}

- (NSArray<XMLElement *> *)query:(NSString *)xpath {
    NSMutableArray *results = [NSMutableArray array];
    
    xmlXPathContextPtr context = xmlXPathNewContext(_xmlDocument);
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
        [results addObject:[[XMLElement alloc] initWithDocument:self node:node]];
    }
    
    xmlXPathFreeObject(object);
    xmlXPathFreeContext(context);
    
    return results;
}

@end

NS_ASSUME_NONNULL_END
