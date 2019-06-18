//
//  CustomFieldTableCell.h
//  Strongbox-iOS
//
//  Created by Mark on 26/03/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfidentialTableCell : UITableViewCell

- (void)setKey:(NSString *)key value:(NSString*)value isConfidential:(BOOL)isConfidential concealed:(BOOL)concealed isEditable:(BOOL)isEditable;

@property (nonatomic, copy, nullable) void (^onConcealedChanged)(BOOL concealed);

@end

NS_ASSUME_NONNULL_END
