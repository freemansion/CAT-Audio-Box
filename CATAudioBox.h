//
//  CATAudioController.h
//  audioRecorder
//
//  Created by carl taylor on 30/12/2013.
//  Copyright (c) 2013 Carl Taylor. All rights reserved.
//

#import <Foundation/Foundation.h>

// ** Audio Format ** //
typedef enum {
    CATAUDIO_BOX_FORMAT_MP3, // < OSX only
    CATAUDIO_BOX_FORMAT_M4A,
    CATAUDIO_BOX_FORMAT_MP4,
    CATAUDIO_BOX_FORMAT_AAC,
    CATAUDIO_BOX_FORMAT_AIFF,
    CATAUDIO_BOX_FORMAT_WAV
} CATAUDIO_BOX_AUDIO_FORMAT;

// ** Error Codes ** //
typedef  enum {
    CATAUDIO_BOX_ERROR_PLAYBACK,
    CATAUDIO_BOX_ERROR_RECORDING
} CATAUDIO_BOX_ERROR_CODE;


@protocol CATAudioBoxDelegate <NSObject>
@optional

-(void)CATAudioBoxDidFinishPlaying;
-(void)CATAudioBoxDidFinishRecording;
-(void)CATAudioBoxError:(CATAUDIO_BOX_ERROR_CODE)errorCode;

@end

@interface CATAudioBox : NSObject

@property (nonatomic, weak) id<CATAudioBoxDelegate>delegate;

@property (nonatomic, strong) NSNumber *maxRecordingTime;

-(id)initWithNumberOfRecordingSlots:(int)recordingSlots andRecordingFormat:(CATAUDIO_BOX_AUDIO_FORMAT)recordingFormat;

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
