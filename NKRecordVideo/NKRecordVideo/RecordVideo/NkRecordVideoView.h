//
//  NkRecordVideoView.h
//  NKRecordVideo
//
//  Created by 聂宽 on 2019/1/15.
//  Copyright © 2019年 聂宽. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^RecordVideoFinish)(NSURL *videoUrl);
@interface NkRecordVideoView : UIView
@property (nonatomic, copy) RecordVideoFinish recordFinish;
@end
