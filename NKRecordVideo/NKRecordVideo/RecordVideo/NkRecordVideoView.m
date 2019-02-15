//
//  NkRecordVideoView.m
//  NKRecordVideo
//
//  Created by 聂宽 on 2019/1/15.
//  Copyright © 2019年 聂宽. All rights reserved.
//

#import "NkRecordVideoView.h"
#import <AVFoundation/AVFoundation.h>

#define sH [UIScreen mainScreen].bounds.size.height
#define sW [UIScreen mainScreen].bounds.size.width
#define ImageWithName(imgStr)  [UIImage imageNamed:[NSString stringWithFormat:@"%@", imgStr]]
@interface NkRecordVideoView()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@property (nonatomic, strong) UIButton *finishBtn;
@property (nonatomic, strong) UIView *topView;

@property (nonatomic, strong) UIButton *recordBtn;
@property (nonatomic, strong) UIButton *pauseBtn;
@property (nonatomic, strong) UIView *bottomView;

// 预览层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previeLayer;

// 捕获绘画
@property (nonatomic, strong) AVCaptureSession *captureSession;
// 视频输入源
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
// 音频输入源
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

// 视频输出
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
// 音频输出
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;

@property (nonatomic, strong) dispatch_queue_t videoQueue;

// 写入
@property (nonatomic, strong) AVAssetWriter *assetWriter;

@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;

@property (nonatomic, strong) NSDictionary *videoCompressionDict;

@property (nonatomic, strong) NSDictionary *audioCompressionDict;

@property (nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;
@property (nonatomic, retain) __attribute__((NSObject)) CMFormatDescriptionRef outputAudioFormatDescription;

@property (nonatomic, assign) BOOL canWrite;
@property (nonatomic, strong) dispatch_queue_t writeQueue;
// 视频存放路径
@property (nonatomic, strong) NSURL *videoUrl;

// 判断是否在record
@property (nonatomic, assign) BOOL isRecord;
@end
static const CGFloat topViewH = 80.0;
static const CGFloat botViewH = 100.0;
@implementation NkRecordVideoView

- (NSURL *)videoUrl
{
    if (_videoUrl == nil) {
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"temp_video.mp4"];
        _videoUrl = [NSURL fileURLWithPath:videoPath];
    }
    return _videoUrl;
}

- (AVCaptureSession *)captureSession
{
    if (_captureSession == nil) {
        _captureSession = [[AVCaptureSession alloc] init];
        
        // 设置分辨率
        if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
            [_captureSession setSessionPreset:AVCaptureSessionPresetHigh];
        }
    }
    return _captureSession;
}

- (dispatch_queue_t)videoQueue
{
    if (_videoQueue == nil) {
        _videoQueue = dispatch_queue_create("com.recordvideo", DISPATCH_QUEUE_SERIAL);
    }
    return _videoQueue;
}

- (dispatch_queue_t)writeQueue
{
    if (_writeQueue == nil) {
        _writeQueue = dispatch_queue_create("com.recordvideo.write", DISPATCH_QUEUE_SERIAL);
    }
    return _writeQueue;
}

- (AVCaptureVideoPreviewLayer *)previeLayer
{
    if (_previeLayer == nil) {
        _previeLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        // 显示模式
        _previeLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _previeLayer;
}

- (UIView *)topView
{
    if (_topView == nil) {
        _topView = [[UIView alloc] init];
    }
    return _topView;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // 设置视频输入输出
        [self setupVideo];
        // 设置音频输入输出
        [self setupAudio];
        // 设置预览层
        [self.layer addSublayer:self.previeLayer];
        // 开始采集
        [self.captureSession startRunning];
        
        // 设置UI
        [self settingUI];
        
        // 设置writer
        [self setupWriter];
    }
    return self;
}

- (void)setupVideo
{
    // 视频输入设备(摄像头)
    AVCaptureDevice *videoDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    // 视频输入源
    NSError *error = nil;
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&error];
    if (error) {
        NSLog(@"----- %@", error.description);
    }
    // 视频输入源添加到会话
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    // 视频输出源
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 立即丢弃旧帧，节省内存
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    // 设置输出源
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoQueue];
    
    // 将视频输出源添加到会话
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
}

- (void)setupAudio
{
    // 获取音频输入设备
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    NSError *error = nil;
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@" ---------- %@", error.description);
    }
    if ([self.captureSession canAddInput:self.audioInput]) {
        [self.captureSession addInput:self.audioInput];
    }
    
    // 音频输入源
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.videoQueue];
    if ([self.captureSession canAddOutput:self.audioDataOutput]) {
        [self.captureSession addOutput:self.audioDataOutput];
    }
}

// 设置写入视频
- (void)setupWriter
{
    _assetWriter = [[AVAssetWriter alloc] initWithURL:self.videoUrl fileType:AVFileTypeMPEG4 error:nil];
    // 视频大小 这里设置屏幕大小
    CGFloat pixels = sW * sH;
    // 每个像素的大小 所占的字节
    CGFloat bitsPixels = 6.0;
    // 设置码率、帧率
    NSDictionary *compressionProperties = @{
                                            AVVideoAverageBitRateKey : @(pixels * bitsPixels),
                                            AVVideoExpectedSourceFrameRateKey : @(30),
                                            AVVideoMaxKeyFrameIntervalKey : @(30),
                                            AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel
                                            };
    // 视频属性
    self.videoCompressionDict = @{
                                  AVVideoCodecKey : AVVideoCodecH264,
                                  AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                  AVVideoWidthKey : @(sH),
                                  AVVideoHeightKey : @(sW),
                                  AVVideoCompressionPropertiesKey : compressionProperties
                                  };
    self.videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:self.videoCompressionDict];
    //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
    self.videoWriterInput.expectsMediaDataInRealTime = YES;
    self.videoWriterInput.transform = CGAffineTransformMakeRotation(M_PI * 0.5);
    // 将视频写入源 添加 到writer
    if ([self.assetWriter canAddInput:self.videoWriterInput]) {
        [self.assetWriter addInput:self.videoWriterInput];
    }
    
    // 音频属性
    self.audioCompressionDict = @{
                                  AVEncoderBitRatePerChannelKey : @(28000),
                                  AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                  AVNumberOfChannelsKey : @(1),
                                  AVSampleRateKey : @(22050)
                                  };
    self.audioWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:self.audioCompressionDict];
    self.audioWriterInput.expectsMediaDataInRealTime = YES;
    // 将音频写入源添加到writer
    if ([self.assetWriter canAddInput:self.audioWriterInput]) {
        [self.assetWriter addInput:self.audioWriterInput];
    }
}

- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!_isRecord) {
        return;
    }
    @autoreleasepool
    {
        if (connection == [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo]) {
            // 加锁 写入视频
            @synchronized(self)
            {
                [self appendSampleBuffer:sampleBuffer withType:AVMediaTypeVideo];
            }
        }else if (connection == [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio])
        {
            // 音频
            @synchronized(self)
            {
                [self appendSampleBuffer:sampleBuffer withType:AVMediaTypeAudio];
            }
        }
    }
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(NSString *)mediaType
{
    if (sampleBuffer == NULL) {
        NSLog(@"传入数据 为 null");
        return;
    }
    CFRetain(sampleBuffer);
    dispatch_async(self.videoQueue, ^{
        @autoreleasepool
        {
            if (!self.canWrite) {
                [self.assetWriter startWriting];
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                self.canWrite = YES;
            }
            // 写入数据
            if (mediaType == AVMediaTypeVideo) {
                if (self.videoWriterInput.readyForMoreMediaData) {
                    BOOL success = [self.videoWriterInput appendSampleBuffer:sampleBuffer];
                }else
                {
                    [self.assetWriter startWriting];
                    [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                    self.canWrite = YES;
                }
            }
            if (mediaType == AVMediaTypeAudio) {
                if (self.audioWriterInput.readyForMoreMediaData) {
                    BOOL success = [self.audioWriterInput appendSampleBuffer:sampleBuffer];
                }
            }
            
            CFRelease(sampleBuffer);
        }
        
    });
}

- (void)distoryAssetWriter
{
    self.assetWriter = nil;
    self.videoWriterInput = nil;
    self.audioWriterInput = nil;
    self.videoUrl = nil;
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate

- (void)settingUI
{
    _topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sW, topViewH)];
    _topView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    [self addSubview:_topView];
    
    _finishBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _finishBtn.tag = 11;
    [_finishBtn setTitle:@"完成" forState:UIControlStateNormal];
    [_finishBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    _finishBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    _finishBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [_finishBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_topView addSubview:_finishBtn];
    
    _bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, sH - botViewH, sW, botViewH)];
    _bottomView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    [self addSubview:_bottomView];
    
    _recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _recordBtn.tag = 12;
    [_recordBtn setImage:ImageWithName(@"video_Record") forState:UIControlStateNormal];
    _recordBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_recordBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_recordBtn];
    
    _pauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _pauseBtn.tag = 13;
    [_pauseBtn setImage:ImageWithName(@"video_Pause") forState:UIControlStateNormal];
    _pauseBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [_pauseBtn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomView addSubview:_pauseBtn];
    _pauseBtn.hidden = YES;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _topView.frame = CGRectMake(0, 0, sW, topViewH);
    _finishBtn.frame = CGRectMake(sW - 70, (topViewH - 40) * 0.5, 60, 40);
    
    _bottomView.frame = CGRectMake(0, sH - botViewH, sW, botViewH);
    CGFloat recordBtnW = 60.0;
    _recordBtn.frame = CGRectMake((sW - recordBtnW) * 0.5, (botViewH - recordBtnW) * 0.5, recordBtnW, recordBtnW);
    _pauseBtn.frame = CGRectMake((sW - recordBtnW) * 0.5, (botViewH - recordBtnW) * 0.5, recordBtnW, recordBtnW);
    
    self.previeLayer.frame = self.bounds;
}

- (void)stopWrite
{
    int status = self.assetWriter.status;
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        dispatch_async(self.videoQueue, ^{
            [self.assetWriter finishWritingWithCompletionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSData *data = [NSData dataWithContentsOfURL:self.videoUrl];
                    NSLog(@"-----%@ ------------ %lu", self.videoUrl.absoluteString, (unsigned long)data.length);
                    if (self.finishBtn) {
                        self.recordFinish(self.videoUrl);
                    }
                });
                [self distoryAssetWriter];
            }];
        });
    }

}

- (void)btnClick:(UIButton *)btn
{
    if (btn.tag == 11) {
        // 完成
        [self stopWrite];
        _isRecord = NO;
        _recordBtn.hidden = NO;
        _pauseBtn.hidden = YES;
    }else if (btn.tag == 12)
    {
        // 录制
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"temp_video.mp4"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtPath:videoPath error:nil];
        
        _isRecord = YES;
        _recordBtn.hidden = YES;
        _pauseBtn.hidden = NO;
        [self.captureSession startRunning];
        if (!self.assetWriter) {
            [self setupWriter];
        }
        
    }else if (btn.tag == 13)
    {
        // 暂停
        _isRecord = NO;
        _recordBtn.hidden = NO;
        _pauseBtn.hidden = YES;
        [self.captureSession stopRunning];
        NSData *data = [NSData dataWithContentsOfURL:self.videoUrl];
        NSLog(@"-----%@ ------------ %lu", self.videoUrl.absoluteString, (unsigned long)data.length);
    }
}
@end
