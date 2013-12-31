//
//  CATAudioController.h
//  audioRecorder
//
//  Created by carl taylor on 30/12/2013.
//  Copyright (c) 2013 Carl Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CATAudioBoxProtocol <NSObject>

@optional

-(void)CATAudioBoxDidFinishPlaying;
-(void)CATAudioBoxDidFinishRecording;

@end

typedef enum {
    CATAUDIO_CONTROLLER_FORMAT_MP3, // < OSX only
    CATAUDIO_CONTROLLER_FORMAT_M4A,
    CATAUDIO_CONTROLLER_FORMAT_AIFF,
    CATAUDIO_CONTROLLER_FORMAT_WAV
} CATAUDIO_CONTROLLER_AUDIO_FORMAT;

@interface CATAudioBox : NSObject

@property (nonatomic, weak) id<CATAudioBoxProtocol>delegate;

@property (nonatomic, strong) NSNumber *maxRecordingTime;

-(id)initWithNumberOfRecordingSlots:(int)recordingSlots andRecordingFormat:(CATAUDIO_CONTROLLER_AUDIO_FORMAT)recordingFormat;

// ** Audio Operations ** //
-(BOOL)recordAudioForSlotNumber:(int)slotNumber;
-(BOOL)playAudioForSlotNumber:(int)slotNumber;
-(void)stopAudio;

// ** File Operations ** //
-(BOOL)audioFilePresentForSlotNumber:(int)slotNumber;
-(void)removeAudioFileForSlotNumber:(int)slotNumber;
-(NSDictionary*)getAllRecordedFiles;
-(void)cleanUpTempAudioFiles;

@end
