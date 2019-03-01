//
//  XmlStrongBoxModelAdaptor.m
//  Strongbox
//
//  Created by Mark on 23/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "XmlStrongBoxModelAdaptor.h"
#import "XmlStrongboxNodeModelAdaptor.h"
#import "Utils.h"
#import "KeePassConstants.h"

@implementation XmlStrongBoxModelAdaptor

- (Node*)fromXmlModelToStrongboxModel:(RootXmlDomainObject*)existingRootXmlDocument
                                                       error:(NSError**)error {
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    
    KeePassGroup * rootXmlGroup = getExistingRootKeePassGroup(existingRootXmlDocument);
    
    Node* rootNode = [adaptor toModel:rootXmlGroup error:error];
    
    if(!rootNode) {
        NSLog(@"Could not build node model from xml root document.");
        
        if (error != nil) {
            *error = [Utils createNSError:@"Could not parse this database." errorCode:-1];
        }
        
        return nil;
    }
    
    return rootNode;
}

- (RootXmlDomainObject*)toXmlModelFromStrongboxModel:(Node*)rootNode
                                         customIcons:(NSDictionary<NSUUID*, NSData*> *)customIcons
                             existingRootXmlDocument:(RootXmlDomainObject *)existingRootXmlDocument
                                             context:(XmlProcessingContext*)context
                                               error:(NSError **)error {
    RootXmlDomainObject *ret = existingRootXmlDocument;
    
    if(!ret) {
        ret = [[RootXmlDomainObject alloc] initWithDefaultsAndInstantiatedChildren:context];
    }

    // 2. Convert from Strongbox Node Model back to Keepass Xml model respecting any existing tags/attributes etc
    
    XmlStrongboxNodeModelAdaptor *adaptor = [[XmlStrongboxNodeModelAdaptor alloc] init];
    KeePassGroup* rootXmlGroup = [adaptor fromModel:rootNode context:context error:error];
    
    if(!rootXmlGroup) {
        NSLog(@"Could not serialize groups/entries.");
        return nil;
    }

    // 3. Metadata
    
    ret.keePassFile.root.rootGroup = rootXmlGroup;
    ret.keePassFile.meta.generator.text = kStrongboxGenerator;
    
    // 4. Custom Icons
    
    if(customIcons.count) {
        if(!ret.keePassFile.meta.customIconList) {
            ret.keePassFile.meta.customIconList = [[CustomIconList alloc] initWithContext:[XmlProcessingContext standardV3Context]];
        }
        
        [ret.keePassFile.meta.customIconList.icons removeAllObjects];
        for (NSUUID* uuid in customIcons.allKeys) {
            NSData* data = customIcons[uuid];
            CustomIcon *icon = [[CustomIcon alloc] initWithContext:[XmlProcessingContext standardV3Context]];
            icon.uuid = uuid;
            icon.data = data;
            
            [ret.keePassFile.meta.customIconList.icons addObject:icon];
        }
    }
    
    return ret;
}

static KeePassGroup *getExistingRootKeePassGroup(RootXmlDomainObject * _Nonnull existingRootXmlDocument) {
    // Possible that one of these intermediates are nil... safety
    
    KeePassFile *keepassFileElement = existingRootXmlDocument == nil ? nil : existingRootXmlDocument.keePassFile;
    Root* rootXml = keepassFileElement == nil ? nil : keepassFileElement.root;
    KeePassGroup *rootXmlGroup = rootXml == nil ? nil : rootXml.rootGroup;
    
    return rootXmlGroup;
}


@end
