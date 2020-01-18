//
//  SampleHandler.m
//  ScreenCapture
//
//  Created by minzhe on 2019/7/31.
//  Copyright © 2019 minzhe. All rights reserved.
//


#import "SampleHandler.h"
#import "LFLiveKit.h"
#import "LFStreamRTMPSocket.h"
#import "LFHardwareVideoEncoder.h"
#import "LFHardwareAudioEncoder.h"
#import "XDXAduioEncoder.h"
#import <UserNotifications/UserNotifications.h>
#import "MixAudioManager.h"
#import <MetalPetal/MetalPetal.h>
#import <sys/sysctl.h>
#import <mach/mach.h>

@interface SampleHandler () <LFStreamSocketDelegate, LFVideoEncodingDelegate, LFAudioEncodingDelegate, MixAudioManagerDelegate>

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@property (nonatomic, strong) id<LFStreamSocket> socket;
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;

@property (nonatomic, strong) id<LFVideoEncoding> videoEncoder;
/// 音频编码
@property (nonatomic, strong) id<LFAudioEncoding> audioEncoder;

@property (nonatomic, strong) XDXAduioEncoder *audioEncoder2;


@property (nonatomic, strong) MixAudioManager *mixAudioManager;

/// 音频配置
@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) LFLiveVideoConfiguration *videoConfiguration;


@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, assign) uint64_t relativeTimestamps;

@property (nonatomic, assign) BOOL canUpload;

@property (nonatomic, strong) dispatch_queue_t rotateQueue;
@property (nonatomic, strong) dispatch_queue_t audioQueue;

@property (nonatomic, assign) size_t videoWidth;
@property (nonatomic, assign) size_t videoHeight;

@property (nonatomic, assign) UIInterfaceOrientation encoderOrientation;
@property (nonatomic, assign) CGImagePropertyOrientation rotateOrientation;

@property (nonatomic, assign) CMSampleBufferRef applicationBuffer;
@property (nonatomic, assign) CMSampleBufferRef micBuffer;

@property (nonatomic, strong) MTIContext *context;

@property (nonatomic, assign) CVPixelBufferPoolRef pixelBufferPool;
@property (nonatomic, assign) BOOL hasPixelBufferPool;

@property (nonatomic, strong) UIImage *filterImage;

@property (nonatomic, strong) NSMutableArray *videoFrameArray;

@property (nonatomic, assign) BOOL isBStatus;

@property (nonatomic, strong) CIContext *ciContext;

/// 音视频是否对齐
@property (nonatomic, assign) BOOL AVAlignment;
/// 当前是否采集到了音频
@property (nonatomic, assign) BOOL hasCaptureAudio;
/// 当前是否采集到了关键帧
@property (nonatomic, assign) BOOL hasKeyFrameVideo;

@property (nonatomic, strong) CIImage *watermarkImage;
@property (nonatomic, assign) BOOL usingWaterMarkImage;

@end

@implementation SampleHandler

- (CIContext *)ciContext {
    if (!_ciContext) {
        _ciContext = [CIContext contextWithOptions:nil];
    }
    return _ciContext;
}

- (CVPixelBufferPoolRef)pixelBufferPool {
    CGFloat width = self.videoHeight;
    CGFloat height = self.videoWidth;
    if (self.rotateOrientation == kCGImagePropertyOrientationUp) {
        width = self.videoWidth;
        height = self.videoHeight;
    }
    CVPixelBufferPoolCreate(kCFAllocatorDefault,
                            nil,
                            (__bridge CFDictionaryRef)@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                                                        (id)kCVPixelBufferWidthKey: @(width),
                                                        (id)kCVPixelBufferHeightKey: @(height),
                                                        (id)kCVPixelFormatOpenGLESCompatibility: @(true),
                                                        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}},
                            &_pixelBufferPool);
    return _pixelBufferPool;
    
}

#pragma mark -- getter
- (MixAudioManager *)mixAudioManager {
    if (!_mixAudioManager) {
        _mixAudioManager = [[MixAudioManager alloc] init];
        _mixAudioManager.delegate = self;
    }
    return _mixAudioManager;
}

- (LFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[LFLiveStreamInfo alloc] init];
        NSString *urlStr = [_userDefaults objectForKey:@"urlStr"];
        if ([urlStr hasSuffix:@"/"]) {
            urlStr = [urlStr substringToIndex:urlStr.length-1];
        }
        _streamInfo.url = urlStr;
    }
    
    return _streamInfo;
}

- (id<LFStreamSocket>)socket {
    if (!_socket) {
        _socket = [[LFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:0 reconnectCount:0];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (id<LFVideoEncoding>)videoEncoder {
    if (!_videoEncoder) {
        _videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:self.videoConfiguration];
        [_videoEncoder setDelegate:self];
        NSLog(@"self.videoConfiguration d方向：%ld", (long)self.videoConfiguration.outputImageOrientation);
    }
    return _videoEncoder;
}

- (LFLiveVideoConfiguration *)videoConfiguration {
    if (!_videoConfiguration) {
        _videoConfiguration = [LFLiveVideoConfiguration defaultConfigurationForQuality:LFLiveVideoQuality_High3 outputImageOrientation:self.encoderOrientation width:self.videoWidth height:self.videoHeight];
    }
    return _videoConfiguration;
    
}

- (id<LFAudioEncoding>)audioEncoder {
    if (!_audioEncoder) {
        _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:self.audioConfiguration];
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (LFLiveAudioConfiguration *)audioConfiguration {
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfiguration];
    }
    return _audioConfiguration;
}

- (UIInterfaceOrientation)encoderOrientation {
    NSInteger screenOrientationValue = [[_userDefaults objectForKey:@"screenOrientationValue"] integerValue];
    UIInterfaceOrientation orientationValue = UIInterfaceOrientationPortrait;
    switch (screenOrientationValue) {
        case 1:
            orientationValue = UIInterfaceOrientationLandscapeLeft;
            break;
        case 2:
            orientationValue = UIInterfaceOrientationLandscapeRight;
            break;
        default:
            break;
    }
    return orientationValue;
}

- (CGImagePropertyOrientation)rotateOrientation {
    NSInteger screenOrientationValue = [[_userDefaults objectForKey:@"screenOrientationValue"] integerValue];
    CGImagePropertyOrientation rotateOrientation = kCGImagePropertyOrientationUp;
    switch (screenOrientationValue) {
        case 1:
            rotateOrientation = kCGImagePropertyOrientationLeft;
            break;
        case 2:
            rotateOrientation = kCGImagePropertyOrientationRight;
            break;
        default:
            break;
    }
    return rotateOrientation;
}


- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    _videoConfiguration = nil;
    _videoEncoder = nil;
    _streamInfo = nil;
    
    if (_socket) {
        [_socket stop];
        _socket = nil;
    }
    
    self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.gunmm.CaptureDeviceProject"];
    self.rotateQueue = dispatch_queue_create("rotateQueue", DISPATCH_QUEUE_SERIAL);
    self.audioQueue = dispatch_queue_create("audioQueue", DISPATCH_QUEUE_SERIAL);
    
    [self.socket start];
    self.relativeTimestamps = 0;
    
    MTIContextOptions *options = [[MTIContextOptions alloc] init];
    NSError *error;
    MTIContext *context = [[MTIContext alloc] initWithDevice:MTLCreateSystemDefaultDevice() options:options error:&error];
    self.context = context;
    
    _videoFrameArray = [NSMutableArray array];
    NSString *urlStr = [_userDefaults objectForKey:@"urlStr"];
    _isBStatus = [urlStr containsString:@"js.live-send.acg.tv"];
    
    if (@available(iOS 13.0, *)) {
        _isBStatus = NO;
    }
    
    self.usingWaterMarkImage = [[_userDefaults objectForKey:@"usingWaterMarkImage"] boolValue];
    if (self.usingWaterMarkImage) {
        NSData *encodedImageStr = [[self.userDefaults objectForKey:@"waterMarkImage"] mutableCopy];
        UIImage *decodedImage = [UIImage imageWithData:encodedImageStr];
        self.watermarkImage = [[CIImage alloc] initWithCGImage:decodedImage.CGImage];
    }

    
   
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
    [self sendLocalNotificationToHostAppWithTitle:@"屏幕推流" msg:@"录屏暂停" userInfo:nil];
    NSLog(@"------Paused-------");
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
    [self sendLocalNotificationToHostAppWithTitle:@"屏幕推流" msg:@"录屏重新开始" userInfo:nil];
    NSLog(@"------Resumed-------");
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
    [self sendLocalNotificationToHostAppWithTitle:@"屏幕推流" msg:@"录屏已结束" userInfo:nil];
    NSLog(@"------Finished-------");
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
        {
            if ([self getMemoryUsage] > 40) {
                return;
            }
            if (self.canUpload) {
               [self dealWithSampleBuffer:sampleBuffer];
            }
        }
            break;
        case RPSampleBufferTypeAudioApp:
            if (_isBStatus) {
                return;
            }
            if (self.canUpload) {
                //从samplebuffer中获取blockbuffer
                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                size_t pcmLength = 0;
                char *pcmData = NULL;
                //获取blockbuffer中的pcm数据的指针和长度
                OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &pcmLength, &pcmData);
                if (status != noErr) {
                    NSLog(@"从block中获取pcm数据失败");
                    return;
                } else {
                    CMAudioFormatDescriptionRef audioFormatDes =  (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer);
                    AudioStreamBasicDescription inAudioStreamBasicDescription = *(CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDes));
                    inAudioStreamBasicDescription.mFormatFlags = 0xe;
                    self.mixAudioManager.appInputFormat = inAudioStreamBasicDescription;
                    [self.mixAudioManager sendAppBufferList:[[NSData alloc] initWithBytes:pcmData length:pcmLength] timeStamp:(CACurrentMediaTime()*1000)];
                }
            }
            break;
        case RPSampleBufferTypeAudioMic:
        {
            if (self.canUpload) {
                //从samplebuffer中获取blockbuffer
                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                size_t pcmLength = 0;
                char *pcmData = NULL;
                //获取blockbuffer中的pcm数据的指针和长度
                OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &pcmLength, &pcmData);
                if (status != noErr) {
                    NSLog(@"从block中获取pcm数据失败");
                    CFRelease(sampleBuffer);
                    return;
                } else {
                    CMAudioFormatDescriptionRef audioFormatDes =  (CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer);
                    AudioStreamBasicDescription inAudioStreamBasicDescription = *(CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDes));
                    //                        NSLog(@"***************** %lu", pcmLength);
                    
                    //                        mFormatFlags: 0xc
                    if (self.isBStatus) {
                        [self.audioEncoder setCustomInputFormat:inAudioStreamBasicDescription];
                        NSData *data = [[NSData alloc] initWithBytes:pcmData length:pcmLength];
                        [self.audioEncoder encodeAudioData:data timeStamp:(CACurrentMediaTime()*1000)];
                    } else {
                        inAudioStreamBasicDescription.mFormatFlags = 0xe;
                        self.mixAudioManager.micInputFormat = inAudioStreamBasicDescription;
                        if (!self.audioEncoder2) {
                            AudioStreamBasicDescription inputFormat = {0};
                            inputFormat.mSampleRate = 44100;
                            inputFormat.mFormatID = kAudioFormatLinearPCM;
                            inputFormat.mFormatFlags = 0xc;
                            inputFormat.mChannelsPerFrame = 1;
                            inputFormat.mFramesPerPacket = 1;
                            inputFormat.mBitsPerChannel = 16;
                            inputFormat.mBytesPerFrame = inputFormat.mBitsPerChannel / 8 * inputFormat.mChannelsPerFrame;
                            inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame * inputFormat.mFramesPerPacket;
                            self.audioEncoder2 = [[XDXAduioEncoder alloc] initWithSourceFormat:inputFormat
                                                                                  destFormatID:kAudioFormatMPEG4AAC
                                                                                    sampleRate:44100
                                                                           isUseHardwareEncode:YES];
                        }
                        ///<  发送
                        AudioBuffer inBuffer;
                        inBuffer.mNumberChannels = 1;
                        inBuffer.mData = pcmData;
                        inBuffer.mDataByteSize = (UInt32)pcmLength;
                        
                        AudioBufferList buffers;
                        buffers.mNumberBuffers = 1;
                        buffers.mBuffers[0] = inBuffer;
                        
                        Float64 currentTime = CMTimeGetSeconds(CMClockMakeHostTimeFromSystemUnits(CACurrentMediaTime()));
                        
                        int64_t pts = (int64_t)((currentTime - 100) * 1000);
                        __weak typeof(self) weakSelf = self;

                        [self.audioEncoder2 encodeAudioWithSourceBuffer:buffers.mBuffers[0].mData sourceBufferSize:buffers.mBuffers[0].mDataByteSize pts:pts completeHandler:^(LFAudioFrame * _Nonnull frame) {
                            if (weakSelf.isBStatus) {
                                NSData *data = [[NSData alloc] initWithBytes:pcmData length:pcmLength];
                                [weakSelf.audioEncoder encodeAudioData:data timeStamp:(CACurrentMediaTime()*1000)];
                            } else {
                                [weakSelf.mixAudioManager sendMicBufferList:frame.data timeStamp:(CACurrentMediaTime()*1000)];
                            }
                        }];
                    }
                }
            }
            break;
        }
            
        default:
            break;
    }
}

#pragma mark -- PrivateMethod
- (void)sendLocalNotificationToHostAppWithTitle:(NSString*)title msg:(NSString*)msg userInfo:(NSDictionary*)userInfo
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = [NSString localizedUserNotificationStringForKey:title arguments:nil];
    content.body = [NSString localizedUserNotificationStringForKey:msg  arguments:nil];
    content.sound = [UNNotificationSound defaultSound];
    content.userInfo = userInfo;
    
    // 在设定时间后推送本地推送
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger
                                                  triggerWithTimeInterval:0.1f repeats:NO];
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"gunmm.CaptureDeviceProject"
                                                                          content:content trigger:trigger];
    //添加推送成功后的处理！
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
    }];
}

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (void)pushSendBuffer:(LFFrame*)frame{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

- (void)dealWithSampleBuffer:(CMSampleBufferRef)buffer {
    if (!CMSampleBufferIsValid(buffer) || !buffer)
        return;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    CGFloat widthScale = width/720.0;
    CGFloat heightScale = height/1280.0;
    CGFloat realWidthScale = 1;
    CGFloat realHeightScale = 1;
    
    if (widthScale > 1 || heightScale > 1) {
        if (widthScale < heightScale) {
            realHeightScale = 1280.0/height;
            CGFloat nowWidth = width * 1280.0 / height;
            height = 1280.0;
            realWidthScale = ceilf(nowWidth)/width;
            width = ceilf(nowWidth);
        } else {
            realWidthScale = 720.0/width;
            CGFloat nowHeight = 720.0 * height / width;
            width = 720.0;
            realHeightScale = ceilf(nowHeight)/height;
            height = ceilf(nowHeight);
        }
    }
    self.videoWidth = width;
    self.videoHeight = height;
    if (NO) {
        if (!_hasPixelBufferPool) {
            _hasPixelBufferPool = YES;
            [self pixelBufferPool];
        }
        
        MTIImageOrientation imageOrientation = MTIImageOrientationUp;
        if (self.rotateOrientation == kCGImagePropertyOrientationUp) {
            if (realWidthScale == 1 && realHeightScale == 1) {
                [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
            } else {
                MTIImage *inputImage = [[MTIImage alloc] initWithCVPixelBuffer:pixelBuffer alphaType:MTIAlphaTypeAlphaIsOne];
                inputImage = [[MTIUnaryImageRenderingFilter imageByProcessingImage:inputImage orientation:imageOrientation parameters:@{} outputPixelFormat:MTIPixelFormatUnspecified outputImageSize:CGSizeMake(width, height)] imageWithCachePolicy:inputImage.cachePolicy];
                
                CVPixelBufferRef outputPixelBuffer = nil;
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pixelBufferPool, &outputPixelBuffer);
                
                NSError *error;
                [self.context renderImage:inputImage toCVPixelBuffer:outputPixelBuffer error:&error];
                
                if (!error) {
                    CMSampleBufferRef outputSampleBuffer = SampleBufferByReplacingImageBuffer(buffer, outputPixelBuffer);
                    CVPixelBufferRef pushPixelBuffer = CMSampleBufferGetImageBuffer(outputSampleBuffer);
                    CVPixelBufferRelease(outputPixelBuffer);
                    [self.videoEncoder encodeVideoData:pushPixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
                    CFRelease(outputSampleBuffer);
                } else {
                    NSLog(@"-------------error");
                }
            }
        } else {
            if (self.rotateOrientation == kCGImagePropertyOrientationLeft) {
                imageOrientation = MTIImageOrientationRight;
            } else {
                imageOrientation = MTIImageOrientationLeft;
            }
            MTIImage *inputImage = [[MTIImage alloc] initWithCVPixelBuffer:pixelBuffer alphaType:MTIAlphaTypeAlphaIsOne];
            inputImage = [[MTIUnaryImageRenderingFilter imageByProcessingImage:inputImage orientation:imageOrientation parameters:@{} outputPixelFormat:MTIPixelFormatUnspecified outputImageSize:CGSizeMake(height, width)] imageWithCachePolicy:inputImage.cachePolicy];
            CVPixelBufferRef outputPixelBuffer = nil;
            CVReturn ok1 = kCVReturnSuccess;
            @autoreleasepool {
                ok1 = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil,
                                                                          _pixelBufferPool,
                                                                          (__bridge CFDictionaryRef)@{
                                                                              (__bridge id)kCVPixelBufferPoolAllocationThresholdKey: @3
                                                                          },
                                                                          &outputPixelBuffer
                                                                          );
            }
            if (ok1 == kCVReturnWouldExceedAllocationThreshold) {
                NSLog(@"-------------------");
                return;
            }
            NSError *error;
            CVPixelBufferLockBaseAddress(outputPixelBuffer, 0);
            [self.context renderImage:inputImage toCVPixelBuffer:outputPixelBuffer error:&error];
            CVPixelBufferUnlockBaseAddress(outputPixelBuffer, 0);
            
            if (!error) {
                CMSampleBufferRef outputSampleBuffer = SampleBufferByReplacingImageBuffer(buffer, outputPixelBuffer);
                CVPixelBufferRef pushPixelBuffer = CMSampleBufferGetImageBuffer(outputSampleBuffer);
                CVPixelBufferRelease(outputPixelBuffer);
                [self.videoEncoder encodeVideoData:pushPixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
                CFRelease(outputSampleBuffer);
            } else {
                NSLog(@"-------------error");
            }
        }
    }
    else {
        if (!_hasPixelBufferPool) {
            _hasPixelBufferPool = YES;
            [self pixelBufferPool];
        }
        CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        if (self.rotateOrientation == kCGImagePropertyOrientationUp) {
            if (realWidthScale == 1 && realHeightScale == 1) {
                [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
            } else {
                CIImage *newImage = [ciimage imageByApplyingTransform:CGAffineTransformMakeScale(realWidthScale, realHeightScale)];
                CVPixelBufferRef newPixcelBuffer = nil;
                CVReturn ok1 = kCVReturnSuccess;
                ok1 = kCVReturnSuccess;
                @autoreleasepool {
                    ok1 = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil,
                                                                              _pixelBufferPool,
                                                                              (__bridge CFDictionaryRef)@{
                                                                                  (__bridge id)kCVPixelBufferPoolAllocationThresholdKey: @3
                                                                              },
                                                                              &newPixcelBuffer
                                                                              );
                }
                
                if (ok1 == kCVReturnWouldExceedAllocationThreshold) {
                    NSLog(@"-------------------");
                    return;
                }
                CVPixelBufferLockBaseAddress(newPixcelBuffer, 0);
                [self.ciContext render:newImage toCVPixelBuffer:newPixcelBuffer];
                CVPixelBufferUnlockBaseAddress(newPixcelBuffer, 0);
                
                CMSampleBufferRef outputSampleBuffer = SampleBufferByReplacingImageBuffer(buffer, newPixcelBuffer);
                CVPixelBufferRef pushPixelBuffer = CMSampleBufferGetImageBuffer(outputSampleBuffer);
                CVPixelBufferRelease(newPixcelBuffer);
                [self.videoEncoder encodeVideoData:pushPixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
                CFRelease(outputSampleBuffer);
            }
        } else {
            // 旋转的方法
            CIImage *wImage = [ciimage imageByApplyingCGOrientation:self.rotateOrientation];
            CIImage *newImage = [wImage imageByApplyingTransform:CGAffineTransformMakeScale(realWidthScale, realHeightScale)];
            if (self.usingWaterMarkImage && self.watermarkImage) {
                CIFilter *watermarkFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
                [watermarkFilter setValue:newImage forKey:kCIInputBackgroundImageKey];
                [watermarkFilter setValue:self.watermarkImage forKey:kCIInputImageKey];
                newImage = watermarkFilter.outputImage;
            }
            
            CVPixelBufferRef newPixcelBuffer = nil;
            CVReturn ok1 = kCVReturnSuccess;
            ok1 = kCVReturnSuccess;
            @autoreleasepool {
                ok1 = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil,
                                                                          _pixelBufferPool,
                                                                          (__bridge CFDictionaryRef)@{
                                                                              (__bridge id)kCVPixelBufferPoolAllocationThresholdKey: @3
                                                                          },
                                                                          &newPixcelBuffer
                                                                          );
            }
            
            if (ok1 == kCVReturnWouldExceedAllocationThreshold) {
                NSLog(@"-------------------");
                return;
            }
            CVPixelBufferLockBaseAddress(newPixcelBuffer, 0);
            [self.ciContext render:newImage toCVPixelBuffer:newPixcelBuffer];
            CVPixelBufferUnlockBaseAddress(newPixcelBuffer, 0);
            
            CMSampleBufferRef outputSampleBuffer = SampleBufferByReplacingImageBuffer(buffer, newPixcelBuffer);
            CVPixelBufferRef pushPixelBuffer = CMSampleBufferGetImageBuffer(outputSampleBuffer);
            CVPixelBufferRelease(newPixcelBuffer);
            [self.videoEncoder encodeVideoData:pushPixelBuffer timeStamp:(CACurrentMediaTime()*1000)];
            CFRelease(outputSampleBuffer);
        }
    }
}

- (BOOL)AVAlignment{
    if(self.hasCaptureAudio && self.hasKeyFrameVideo) return YES;
    else  return NO;
}

- (double)getMemoryUsage {
    task_vm_info_data_t vmInfo;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if(task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &vmInfo, &count) == KERN_SUCCESS) {
        return (double)vmInfo.phys_footprint / (1024 * 1024);
    } else {
        return -1.0;
    }
}

#pragma mark -- MixAudioManagerDelegate
- (void)mixDidOutputModel:(MixAudioModel *)mixAudioModel {
    [self.audioEncoder setCustomInputFormat:self.mixAudioManager.currentInputFormat];
    [self.audioEncoder encodeAudioData:mixAudioModel.videoData timeStamp:mixAudioModel.timeStamp];
}

#pragma mark -- LFVideoEncodingDelegate
- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame {
    //    if ([self getMemoryUsage] > 30) {
    //        return;
    //    }
    if (self.canUpload) {
        if (self.hasCaptureAudio == YES) {
            if(frame.isKeyFrame) self.hasKeyFrameVideo = YES;
        }
        
        if(self.AVAlignment) {
            [self pushSendBuffer:frame];
        }
    }
}
#pragma mark -- LFAudioEncodingDelegate
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame {
    //    if ([self getMemoryUsage] > 30) {
    //        return;
    //    }
    if (self.canUpload){
        self.hasCaptureAudio = YES;
        if(self.AVAlignment){
            [self pushSendBuffer:frame];
        }
    }
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    NSLog(@"--------%lu", status);
    
    if (status == LFLiveStart) {
        if (!self.canUpload) {
            self.AVAlignment = NO;
            self.hasCaptureAudio = NO;
            self.hasKeyFrameVideo = NO;
            self.relativeTimestamps = 0;
            self.canUpload = YES;
        }
    } else if(status == LFLiveStop || status == LFLiveError){
        self.canUpload = NO;
        [self sendLocalNotificationToHostAppWithTitle:@"屏幕推流" msg:@"连接错误，推流已停止" userInfo:nil];
    }
}

- (void)socketDidError:(nullable id<LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode {
    
}

- (void)socketDebug:(nullable id<LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo {
    
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveBuffferState)status {
    if (self.canUpload) {
        NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
        if (status == LFLiveBuffferDecline) {
//            if (videoBitRate < _videoConfiguration.videoMaxBitRate) {
//                videoBitRate = videoBitRate + 50 * 1000;
//                [self.videoEncoder setVideoBitRate:videoBitRate];
//                NSLog(@"Increase bitrate %@", @(videoBitRate));
//            }
        } else {
            if (videoBitRate > self.videoConfiguration.videoMinBitRate) {
                videoBitRate = videoBitRate - 100 * 1000;
                [self.videoEncoder setVideoBitRate:videoBitRate];
                NSLog(@"Decline bitrate %@", @(videoBitRate));
            }
        }
    }
}

static CMSampleBufferRef SampleBufferByReplacingImageBuffer(CMSampleBufferRef sampleBuffer, CVPixelBufferRef imageBuffer) {
    CMSampleTimingInfo timeingInfo;
    CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timeingInfo);
    CMSampleBufferRef outputSampleBuffer = NULL;
    CMFormatDescriptionRef formatDescription;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, imageBuffer, &formatDescription);
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, imageBuffer, formatDescription, &timeingInfo, &outputSampleBuffer);
    CFRelease(formatDescription);
    return (CMSampleBufferRef)outputSampleBuffer;
}

@end
