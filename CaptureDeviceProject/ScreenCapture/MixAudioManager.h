//
//  MixAudioManager.h
//  ScreenCapture
//
//  Created by minzhe on 2019/8/28.
//  Copyright © 2019 minzhe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MixAudioModel.h"


NS_ASSUME_NONNULL_BEGIN

@protocol MixAudioManagerDelegate <NSObject>

- (void)mixDidOutputModel:(MixAudioModel *)mixAudioModel;

@end

@interface MixAudioManager : NSObject

@property (nonatomic, weak) id<MixAudioManagerDelegate> delegate;

@property (nonatomic, assign) AudioStreamBasicDescription micInputFormat;
@property (nonatomic, assign) AudioStreamBasicDescription appInputFormat;
@property (nonatomic, assign) AudioStreamBasicDescription currentInputFormat;

- (void)sendMicBufferList:(NSData *)audioData timeStamp:(uint64_t)timeStamp;
- (void)sendAppBufferList:(NSData *)audioData timeStamp:(uint64_t)timeStamp;

@end

NS_ASSUME_NONNULL_END
