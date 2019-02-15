//
//  ResultViewController.m
//  NKRecordVideo
//
//  Created by 聂宽 on 2019/1/15.
//  Copyright © 2019年 聂宽. All rights reserved.
//

#import "ResultViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ResultViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@end

@implementation ResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.player = [[AVPlayer alloc] initWithURL:self.videoUrl];
    // 获取系统声音
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    CGFloat currentVolume = audioSession.outputVolume;
    self.player.volume = currentVolume;
    
    self.playerLayer = [[AVPlayerLayer alloc] init];
    self.playerLayer.frame = self.view.bounds;
    self.playerLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5].CGColor;
    [self.view.layer addSublayer:self.playerLayer];
    
    self.playerLayer.player = self.player;
    
    _playerItem = [[AVPlayerItem alloc] initWithURL:self.videoUrl];
    [self.player replaceCurrentItemWithPlayerItem:_playerItem];
    
    [_player play];
    
    UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [exitBtn setImage:[UIImage imageNamed:@"close_Video"] forState:UIControlStateNormal];
    exitBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [exitBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    exitBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.view addSubview:exitBtn];
    exitBtn.frame = CGRectMake(20, 30, 60, 40);
}

- (void)btnClick:(UIButton *)btn {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

/*


*/

@end
