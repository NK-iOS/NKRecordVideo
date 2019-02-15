//
//  ViewController.m
//  NKRecordVideo
//
//  Created by 聂宽 on 2019/1/15.
//  Copyright © 2019年 聂宽. All rights reserved.
//

#import "ViewController.h"
#import "NkRecordVideoView.h"
#import "ResultViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NkRecordVideoView *recordView = [[NkRecordVideoView alloc] initWithFrame:self.view.bounds];
    __weak typeof(self) weakSelf = self;
    recordView.recordFinish = ^(NSURL *videoUrl) {
        ResultViewController *vc = [[ResultViewController alloc] init];
        vc.videoUrl = videoUrl;
        [weakSelf presentViewController:vc animated:YES completion:nil];
    };
    [self.view addSubview:recordView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
