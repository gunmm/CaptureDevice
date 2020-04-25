//
//  MixAudioManager.m
//  ScreenCapture
//
//  Created by minzhe on 2019/8/28.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import "MixAudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface MixAudioManager ()
{
    NSInteger leftLength;
    char *leftBuf;
}

@property (nonatomic, strong) NSMutableArray *micModelArray;
@property (nonatomic, assign) BOOL isMic;

@end

@implementation MixAudioManager


- (instancetype)init {
    if (self = [super init]) {
        [self configManager];
    }
    return self;
}

- (void)configManager {
    _micModelArray = [NSMutableArray array];
}

- (void)sendMicBufferList:(NSData *)audioData timeStamp:(uint64_t)timeStamp {
    if (self.appAudioStreamBasicDescription.mSampleRate == 0 || self.micAudioStreamBasicDescription.mSampleRate == 0) {
        return;
    }
    
    if (self.appAudioStreamBasicDescription.mSampleRate == self.micAudioStreamBasicDescription.mSampleRate) {
        MixAudioModel *model = [[MixAudioModel alloc] init];
        model.videoData = audioData;
        model.timeStamp = timeStamp;
        [_micModelArray addObject:model];
        _isMic = YES;
    } else {
        if (self.micAudioStreamBasicDescription.mSampleRate > self.appAudioStreamBasicDescription.mSampleRate) {
            NSInteger targetSize = round(2048 * self.micAudioStreamBasicDescription.mSampleRate / self.appAudioStreamBasicDescription.mSampleRate);
            if (targetSize % 2 != 0) {
                targetSize += 1;
            }
            if (!leftBuf) {
                leftBuf = malloc(targetSize);
            }
            NSInteger spaceSize = ceil(targetSize/((targetSize - 2048.0)/2.0));
            char *outModelBuf = malloc(2048);
            
            if (leftLength + audioData.length >= targetSize) {
                NSInteger totalSize = leftLength + audioData.length;
                char *totalBuf = malloc(totalSize);
                
                memcpy(totalBuf, leftBuf, leftLength);
                memcpy(totalBuf + leftLength, audioData.bytes, audioData.length);
                int i = 0;
                
                for (int j = 0; j < targetSize;) {
                    int aaa = totalBuf[j];
                    if (i < 2048) {
                        outModelBuf[i] = aaa;
                        
                        i ++;
                    }
                    if ((j+1)%spaceSize == 0) {
                        j = j + 3;
                    } else {
                        j++;
                    }
                    
                }
                leftLength = totalSize - targetSize;
                memset(leftBuf, 0, targetSize);
                memcpy(leftBuf, totalBuf + (totalSize -leftLength), leftLength);
                free(totalBuf);
                
                MixAudioModel *model = [[MixAudioModel alloc] init];
                model.videoData = [[NSData alloc] initWithBytes:outModelBuf length:2048];
                free(outModelBuf);
                
                model.timeStamp = timeStamp;
                [_micModelArray addObject:model];
                _isMic = YES;
            } else {
                ///< 积累
                memcpy(leftBuf+leftLength, audioData.bytes, audioData.length);
                leftLength = leftLength + audioData.length;
            }
        } else {
            MixAudioModel *model = [[MixAudioModel alloc] init];
            model.videoData = audioData;
            model.timeStamp = timeStamp;
            [_micModelArray addObject:model];
            _isMic = YES;
        }
    }
}

- (void)sendAppBufferList:(NSData *)audioData timeStamp:(uint64_t)timeStamp {
    NSInteger kLength = 2048;
    if (@available(iOS 13.0, *)) {
        if (_micModelArray.count > 0) {
            kLength = 4096;
            //
            BOOL isInReceiver = [self isInReceiverPluggedIn];
            if (!isInReceiver) {
                int const MAX = 32767;
                int const MIN = -32768;
                short app1 = 0, mic1 = 0, app2 = 0, mic2 = 0;
                for (int i = 0; i < 1; i ++) {
                    char *appBuf = malloc(audioData.length);
                    memcpy(appBuf, audioData.bytes, audioData.length);
                    
                    MixAudioModel *model = _micModelArray[i];
                    char *totalModelBuf = malloc(model.videoData.length);
                    memcpy(totalModelBuf, model.videoData.bytes, model.videoData.length);
                    char *outModelBuf = malloc(kLength);
                    int k = 0;
                    for (int j = 0; j < model.videoData.length; j+=2) {
                        if (k < kLength) {
                            app1 = 0xFF00 & (appBuf[k] << 8);
                            app1 += (appBuf[k+1] & 0x00FF);
                            app2 = 0xFF00 & (appBuf[k+2] << 8);
                            app2 += (appBuf[k+3] & 0x00FF);
                            
                            mic1 = 0xFF00 & (totalModelBuf[j] << 8);
                            mic1 += (totalModelBuf[j+1] & 0x00FF);
                            mic2 = 0xFF00 & (totalModelBuf[j] << 8);
                            mic2 += (totalModelBuf[j+1] & 0x00FF);
                            
                            app1 = app1*0.2 + mic1;
                            app2 = app2*0.2 + mic2;
                            if (app1 > MAX)
                            {
                                app1 = MAX;
                            }
                            if (app1 < MIN)
                            {
                                app1 = MIN;
                            }
                            if (app2 > MAX)
                            {
                                app2 = MAX;
                            }
                            if (app2 < MIN)
                            {
                                app2 = MIN;
                            }
                            
                            outModelBuf[k] = ((short)((app1&0xFF00)>>8));
                            outModelBuf[k+1] = ((short)app1&0x00FF);
                            outModelBuf[k+2] = ((short)((app2&0xFF00)>>8));
                            outModelBuf[k+3] = ((short)app2&0x00FF);
                        } else {
                            break;
                        }
                        k += 4;
                    }
                    free(totalModelBuf);
                    free(appBuf);
                    model.videoData = [[NSData alloc] initWithBytes:outModelBuf length:kLength];
                    model.timeStamp = (CACurrentMediaTime()*1000);
                    free(outModelBuf);
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(mixDidOutputModel:)]) {
                        [self.delegate mixDidOutputModel:model];
                    }
                }
                [_micModelArray removeObjectAtIndex:0];
            } else {
                for (int i = 0; i < 1; i ++) {
                    MixAudioModel *model = _micModelArray[i];
                    char *totalModelBuf = malloc(model.videoData.length);
                    memcpy(totalModelBuf, model.videoData.bytes, model.videoData.length);
                    char *outModelBuf = malloc(kLength);
                    int k = 0;
                    for (int j = 0; j < model.videoData.length; j+=2) {
                        if (k < kLength) {
                            outModelBuf[k] = totalModelBuf[j];
                            outModelBuf[k+1] = totalModelBuf[j+1];
                            outModelBuf[k+2] = totalModelBuf[j];
                            outModelBuf[k+3] = totalModelBuf[j+1];
                        } else {
                            break;
                        }
                        k += 4;
                    }
                    free(totalModelBuf);
                    model.videoData = [[NSData alloc] initWithBytes:outModelBuf length:kLength];
                    model.timeStamp = (CACurrentMediaTime()*1000);
                    free(outModelBuf);
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(mixDidOutputModel:)]) {
                        [self.delegate mixDidOutputModel:model];
                    }
                }
                [_micModelArray removeObjectAtIndex:0];
            }
            if (_micModelArray.count > 4) {
                [_micModelArray removeObjectAtIndex:1];
                [_micModelArray removeObjectAtIndex:3];

            }
        }
        else {
            if (!_isMic) {
                MixAudioModel *model = [[MixAudioModel alloc] init];
                model.videoData = audioData;
                model.timeStamp = (CACurrentMediaTime()*1000);
                if (self.delegate && [self.delegate respondsToSelector:@selector(mixDidOutputModel:)]) {
                    [self.delegate mixDidOutputModel:model];
                }
            }
        }
    } else {
        kLength = 2048;
        NSInteger totalSize = audioData.length;
        NSInteger encodeCount = totalSize/kLength;
        char *totalBuf = malloc(totalSize);
        char *p = totalBuf;
        memcpy(totalBuf, audioData.bytes, audioData.length);
        
        if (_micModelArray.count > 0) {
            BOOL isInReceiver = [self isInReceiverPluggedIn];
            for (NSInteger i = 0;i < _micModelArray.count;i++) {
                MixAudioModel *model = _micModelArray[i];
                
                char *totalModelBuf = malloc(model.videoData.length);
                memcpy(totalModelBuf, model.videoData.bytes, model.videoData.length);
                int const MAX = 32767;
                int const MIN = -32768;
                short app = 0, mic = 0;
                for (int j = 0; j < model.videoData.length; j+=2) {
                    if (i < encodeCount && !isInReceiver) {
                        //                if (i < encodeCount) {
                        
                        mic = 0xFF00 & (totalModelBuf[j] << 8);
                        mic += (totalModelBuf[j+1] & 0x00FF);
                        app = 0xFF00 & (p[j] << 8);
                        app += (p[j+1] & 0x00FF);
                        app = app*0.2 + mic;
                        if (app > MAX)
                        {
                            app = MAX;
                        }
                        if (app < MIN)
                        {
                            app = MIN;
                        }
                        
                        totalModelBuf[j] = ((short)((app&0xFF00)>>8));
                        totalModelBuf[j+1] = ((short)app&0x00FF);
                    } else {
                        totalModelBuf[j] = totalModelBuf[j];
                        totalModelBuf[j+1] = totalModelBuf[j+1];
                    }
                    
                }
                model.videoData = [[NSData alloc] initWithBytes:totalModelBuf length:model.videoData.length];
                model.timeStamp = (CACurrentMediaTime()*1000);;
                free(totalModelBuf);
                if (self.delegate && [self.delegate respondsToSelector:@selector(mixDidOutputModel:)]) {
                    [self.delegate mixDidOutputModel:model];
                }
                if (i < encodeCount) {
                    p += kLength;
                }
            }
        } else {
            for(NSInteger index = 0;index < encodeCount;index++){
                char *totalModelBuf = malloc(kLength);
                memcpy(totalModelBuf, p, kLength);
                if (self.delegate && [self.delegate respondsToSelector:@selector(mixDidOutputModel:)]) {
                    MixAudioModel *model = [[MixAudioModel alloc] init];
                    model.videoData = [[NSData alloc] initWithBytes:totalModelBuf length:kLength];
                    model.timeStamp = (CACurrentMediaTime()*1000);
                    [self.delegate mixDidOutputModel:model];
                }
                free(totalModelBuf);
                p += kLength;
            }
        }
        free(totalBuf);
        [_micModelArray removeAllObjects];
    }

}

- (BOOL)isInReceiverPluggedIn {
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [route outputs]) {

        if ([[desc portType] isEqualToString:AVAudioSessionPortBuiltInReceiver] || [[desc portType] isEqualToString:AVAudioSessionPortBuiltInSpeaker])
            return YES;
    }
    return NO;
}

@end
