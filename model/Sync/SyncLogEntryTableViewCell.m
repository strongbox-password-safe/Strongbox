//
//  SyncLogEntryTableViewCell.m
//  Strongbox
//
//  Created by Strongbox on 10/08/2020.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "SyncLogEntryTableViewCell.h"

@interface SyncLogEntryTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *logLabel;
@property (weak, nonatomic) IBOutlet UIImageView *stateImage;
@property (weak, nonatomic) IBOutlet UILabel *timestampLabel;

@end

@implementation SyncLogEntryTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    
    
}

- (void)setState:(SyncOperationState)state log:(NSString*)log timestamp:(NSString*)timestamp {
    self.logLabel.text = log;
    self.timestampLabel.text = timestamp;
    [self setStateLabelBasedOnState:state];
    [self setImageBasedOnState:state];
}

- (void)setStateLabelBasedOnState:(SyncOperationState)state {
    self.stateLabel.text = syncOperationStateToString(state);
}

- (void)setImageBasedOnState:(SyncOperationState)state {
    switch(state) {
        case kSyncOperationStateInProgress:
            self.stateImage.image = [UIImage imageNamed:@"syncronize"];
            self.stateImage.tintColor = UIColor.systemBlueColor;
            break;
        case kSyncOperationStateUserCancelled:
        case kSyncOperationStateBackgroundButUserInteractionRequired:
            self.stateImage.image = [UIImage imageNamed:@"syncronize"];
            self.stateImage.tintColor = UIColor.systemYellowColor;
            break;
        case kSyncOperationStateError:
            self.stateImage.image = [UIImage imageNamed:@"error"];
            self.stateImage.tintColor = UIColor.systemRedColor;
            break;
        case kSyncOperationStateInitial:
            self.stateImage.image = [UIImage imageNamed:@"ok"];
            self.stateImage.tintColor = UIColor.systemBlueColor;
        case kSyncOperationStateDone:
        default:
            self.stateImage.image = [UIImage imageNamed:@"ok"];
            self.stateImage.tintColor = UIColor.systemGreenColor;
            break;
    }
}

@end
