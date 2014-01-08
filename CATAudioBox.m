//
//  CATAudioController.m
//  audioRecorder
//
//  Created by carl taylor on 30/12/2013.
//  Copyright (c) 2013 Carl Taylor. All rights reserved.
//

#import "CATAudioBox.h"
#import <TheAmazingAudioEngine.h>
#import <AERecorder.h>

@interface CATAudioBox ()

@property (nonatomic, strong) NSMutableDictionary *recordedFilesTrackerDict;

@property (nonatomic, strong) NSMutableArray *tempFilePathsArray;

@property (nonatomic, strong) NSTimer *recordingTimer;

@property (nonatomic, strong) AEAudioController *audioController;

@property (nonatomic, strong) AERecorder *recorder;

@property (nonatomic, strong) AEAudioFilePlayer *player;

@property AEChannelGroupRef mainChannelGroup;

@property int numberOfrecordingSlotsAvailable;

@property CATAUDIO_BOX_AUDIO_FORMAT recordingFormat;

@end

@implementation CATAudioBox

#pragma mark - Initialzsation

-(id)initWithNumberOfRecordingSlots:(int)recordingSlots andRecordingFormat:(CATAUDIO_BOX_AUDIO_FORMAT)recordingFormat;
{
    self = [super init];
    if (self != nil) {
        
        [self initializeAudioEngine];
        
        self.numberOfrecordingSlotsAvailable = recordingSlots;
        self.recordingFormat = recordingFormat;
        
        [self createTempAudioFilePathArrayWithCapacity:recordingSlots];
        [self initialiseRecordedFilesTrackingDictWithCapacity:recordingSlots];
        
    }
    return self;
}

-(void)initializeAudioEngine
{
    self.audioController = [[AEAudioController alloc]
                            initWithAudioDescription:[AEAudioController interleaved16BitStereoAudioDescription]
                            inputEnabled:YES];
    
    NSError *error = NULL;
    BOOL result = [_audioController start:&error];
    if (!result) {
        NSLog(@"Error starting TAAE");
    }
}

-(void)initializeChannelGroup
{
    self.mainChannelGroup = [_audioController createChannelGroup];
}

-(void)initialiseRecordedFilesTrackingDictWithCapacity:(int)capacity
{
    self.recordedFilesTrackerDict = [[NSMutableDictionary alloc]initWithCapacity:capacity];
    
    for (int i = 0; i < capacity; i++) {
        NSString *key = [NSString stringWithFormat:@"%d", i];
        [self.recordedFilesTrackerDict setObject:[NSNumber numberWithBool:NO] forKey:key];
    }
}

#pragma mark - Temp File Paths For Recorded Audio

-(void)createTempAudioFilePathArrayWithCapacity:(int)capacity
{
    self.tempFilePathsArray = [[NSMutableArray alloc]init];
    
    for (int i = 0; i < capacity; i++) {
        [self.tempFilePathsArray addObject:[self createFilePathStringWithNumber:i]];
    }
}

-(NSString*)createFilePathStringWithNumber:(int)number
{
    NSString *soundFileName = [NSString stringWithFormat:@"catAudio_soundFileNo_%d_%@.%@",number, [self createRandomInternalStringRef], [self getFileFormatFileExtension]];
    NSString *soundFilePath = [[self getTempAudioFilesDirectory] stringByAppendingPathComponent:soundFileName];
    return soundFilePath;
}

-(NSString*)getTempAudioFilesDirectory
{
    NSArray *dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [dirPaths objectAtIndex:0];
}

-(NSString*)createRandomInternalStringRef
{
    NSString *alphabet  = @"abcdefABCDEF0123456789";
    NSMutableString *randomInternalRef = [NSMutableString stringWithCapacity:8];
    for (NSUInteger i = 0U; i < 8; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [randomInternalRef appendFormat:@"%C", c];
    }
    return randomInternalRef;
}

#pragma mark - Audio Operations

-(BOOL)recordAudioForSlotNumber:(int)slotNumber
{
    if (slotNumber <= self.numberOfrecordingSlotsAvailable) {
        
        if (!self.recorder) {
            
            [self initializeChannelGroup];
            
            self.recorder = [[AERecorder alloc] initWithAudioController:_audioController];
            
            NSString *filePath = [self.tempFilePathsArray objectAtIndex:slotNumber];
            
            NSError *error = NULL;
            if (![_recorder beginRecordingToFileAtPath:filePath
                                              fileType:[self getFileFormatType]
                                                 error:&error] ) {
                NSLog(@"Error setting up TAAE sound recorder: %@", [error localizedDescription]);
                [self.delegate CATAudioBoxError:CATAUDIO_BOX_ERROR_RECORDING];
                return NO;
            }
            
            [_audioController setVolume:1 forChannelGroup:self.mainChannelGroup];
            [_audioController addFilter:[self addHighPassFilter] toChannelGroup:self.mainChannelGroup];
            [_audioController addFilter:[self addCompressor]toChannelGroup:self.mainChannelGroup];
            [_audioController addFilter:[self addLimiter]toChannelGroup:self.mainChannelGroup];   // are these effects added in parallel or serial? need to investigate
            [_audioController addInputReceiver:_recorder];
            
            [self.recordedFilesTrackerDict setObject:@YES forKey:[NSString stringWithFormat:@"%d",slotNumber]];
            
            if (self.maxRecordingTime) {
                [self addRecordStopTimerFiringAfterTime:self.maxRecordingTime.intValue];
            }
        }
    } else {
        [self showLogMessageUserIsTryingToUseSlotOutOfRange];
        return NO;
    }
    
    return YES;
}

-(BOOL)playAudioForSlotNumber:(int)slotNumber
{
    if (slotNumber <= self.numberOfrecordingSlotsAvailable) {
        
        NSString *recordedSlotKey = [NSString stringWithFormat:@"%d", slotNumber];
        BOOL recordingRegisteredInTrackingDict = [[self.recordedFilesTrackerDict valueForKey:recordedSlotKey]boolValue];
        
        if (recordingRegisteredInTrackingDict) {
            
            [self stopAudio];
            
            NSURL *filePath = [[NSURL alloc]initFileURLWithPath:[self.tempFilePathsArray objectAtIndex:slotNumber]];
            self.player     = [AEAudioFilePlayer audioFilePlayerWithURL:filePath
                                                        audioController:_audioController
                                                                  error:NULL];
            if (self.player) {
                NSArray *array = @[self.player];
                [self.audioController addChannels:array];
                
                __weak CATAudioBox *weakSelf = self;
                self.player.completionBlock = ^(void){
                    [weakSelf.delegate CATAudioBoxDidFinishPlaying];
                    
                };
            } else {
                NSLog(@"Error playing TAAE sound file");
                [self.delegate CATAudioBoxError:CATAUDIO_BOX_ERROR_PLAYBACK];
                return NO;
            }
        }
    } else {
        [self showLogMessageUserIsTryingToUseSlotOutOfRange];
        return NO;
    }
    return YES;
}

-(void)stopAudio
{
    if (self.recorder) {
        [self endRecording];
    } else if (self.player.channelIsPlaying) {
        NSArray *array = @[self.player];
        [self.audioController removeChannels:array];
    }
}

-(void)endRecording
{
    [self invalidateRecordStopTimer];
    [self triggerVolumeFade];
}

-(void)triggerVolumeFade
{
    float mainGroupVolume = [_audioController volumeForChannelGroup:self.mainChannelGroup];
    
    if (mainGroupVolume > 0.0f) {
        
        [self setVolume:(mainGroupVolume - 0.1) OnChanelGroup:self.mainChannelGroup];
        
        double delayInSeconds = 0.05;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self triggerVolumeFade];
        });
        
    } else {
        [self removeAudioRecorder];
        [self.delegate CATAudioBoxDidFinishRecording];
    }
}

-(void)setVolume:(float)volume OnChanelGroup:(AEChannelGroupRef)channelGroup
{
    [_audioController setVolume:volume forChannelGroup:channelGroup];
}

-(void)removeAudioRecorder
{
    [_audioController removeInputReceiver:_recorder];
    [_recorder finishRecording];
    self.recorder = nil;
}

#pragma mark - Recording Stop Timer

-(void)addRecordStopTimerFiringAfterTime:(int)seconds
{
    self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(endRecording) userInfo:nil repeats:NO];
}

-(void)invalidateRecordStopTimer
{
    [self.recordingTimer invalidate];
    self.recordingTimer = nil;
}

#pragma mark - File Format Types

-(AudioFileTypeID)getFileFormatType
{
    AudioFileTypeID audioFileType = 0;
    
    switch (self.recordingFormat) {
        case CATAUDIO_BOX_FORMAT_MP3:
            NSAssert(!TARGET_OS_MAC,@"MP3 encoding can only be used on OSX (unless you have an 3rd party codec) sorry");
            audioFileType = kAudioFileMP3Type;
            break;
        case CATAUDIO_BOX_FORMAT_M4A:
            audioFileType = kAudioFileM4AType;
            break;
        case CATAUDIO_BOX_FORMAT_MP4:
            audioFileType = kAudioFileMPEG4Type;
            break;
        case CATAUDIO_BOX_FORMAT_AAC:
            audioFileType = kAudioFileAAC_ADTSType;
            break;
        case CATAUDIO_BOX_FORMAT_AIFF:
            audioFileType = kAudioFileAIFFType;
            break;
        case CATAUDIO_BOX_FORMAT_WAV:
            audioFileType = kAudioFileWAVEType;
            break;
        default:
            audioFileType = kAudioFileAIFFType;
            break;
    }
    return audioFileType;
}

-(NSString*)getFileFormatFileExtension
{
    NSString *audioFileExtension;
    
    switch (self.recordingFormat) {
        case CATAUDIO_BOX_FORMAT_MP3:
            audioFileExtension = @"mp3";
            break;
        case CATAUDIO_BOX_FORMAT_M4A:
            audioFileExtension = @"m4a";
            break;
        case CATAUDIO_BOX_FORMAT_MP4:
            audioFileExtension = @"mp4";
            break;
        case CATAUDIO_BOX_FORMAT_AAC:
            audioFileExtension = @"aac";
            break;
        case CATAUDIO_BOX_FORMAT_AIFF:
            audioFileExtension = @"aiff";
            break;
        case CATAUDIO_BOX_FORMAT_WAV:
            audioFileExtension = @"wav";
            break;
        default:
            audioFileExtension = @"aiff";
            break;
    }
    return audioFileExtension;
}

#pragma mark - File Operations

-(BOOL)audioFilePresentForSlotNumber:(int)slotNumber
{
    NSString *recordedSlotKey = [NSString stringWithFormat:@"%d",slotNumber];
    BOOL audioExists = [[self.recordedFilesTrackerDict valueForKey:recordedSlotKey]boolValue];
    return audioExists;
}

-(void)removeAudioFileForSlotNumber:(int)slotNumber;
{
    if (slotNumber <= self.numberOfrecordingSlotsAvailable) {
        NSString *key = [NSString stringWithFormat:@"%d", slotNumber];
        [self.recordedFilesTrackerDict setObject:[NSNumber numberWithBool:NO] forKey:key];
        [self removeFileAtFilePath:[self.tempFilePathsArray objectAtIndex:slotNumber]];
    } else {
        [self showLogMessageUserIsTryingToUseSlotOutOfRange];
    }
}

-(NSDictionary*)getAllRecordedFiles
{
    NSMutableDictionary *recordedTracksDict = [[NSMutableDictionary alloc]init];
    
    [self.recordedFilesTrackerDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *trackExists, BOOL *stop) {
        
        if (trackExists.boolValue) {
            NSData *audioData  = [[NSData alloc]initWithContentsOfFile:[self.tempFilePathsArray objectAtIndex:key.intValue]];
            [recordedTracksDict setObject:audioData forKey:key];
        }
    }];
    
    
    
    return [recordedTracksDict copy];
}

-(void)cleanUpTempAudioFiles
{
    for (NSString *filePath in self.tempFilePathsArray) {
        [self removeFileAtFilePath:filePath];
    }
    
    for (int i = 0; i < self.numberOfrecordingSlotsAvailable; i++) {
        NSString *key = [NSString stringWithFormat:@"%d", i];
        [self.recordedFilesTrackerDict setObject:@NO forKey:key];
    }
}

-(void)removeFileAtFilePath:(NSString*)filePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    [fileManager removeItemAtPath:filePath error:&error];
}

#pragma mark - Messages

-(void)showLogMessageUserIsTryingToUseSlotOutOfRange
{
    NSLog(@"Error: selected slot exceeds max slots created during initialisation");
}

#pragma mark - Audio Effects

-(AEAudioUnitFilter*)addHighPassFilter
{
    AudioComponentDescription component = AEAudioComponentDescriptionMake
    (kAudioUnitManufacturer_Apple,kAudioUnitType_Effect,kAudioUnitSubType_HighPassFilter);
    
    
    NSError *error = NULL;
    AEAudioUnitFilter *filter = [[AEAudioUnitFilter alloc]
                                 initWithComponentDescription:component
                                 audioController:_audioController
                                 error:&error];
    if (!filter) {
        NSLog(@"Error setting up highpass filter: %@", [error localizedDescription]);
    } else {
        AudioUnitSetParameter(filter.audioUnit,
                              kHipassParam_CutoffFrequency,
                              kAudioUnitScope_Global,
                              0,
                              20.0f, // Hz
                              0);
    }
    
    return filter;
}

-(AEAudioUnitFilter*)addCompressor
{
    AudioComponentDescription component = AEAudioComponentDescriptionMake
    (kAudioUnitManufacturer_Apple,kAudioUnitType_Effect,kAudioUnitSubType_PeakLimiter);
    
    
    NSError *error = NULL;
    AEAudioUnitFilter *compressor = [[AEAudioUnitFilter alloc]
                                     initWithComponentDescription:component
                                     audioController:_audioController
                                     error:&error];
    if (!compressor) {
        NSLog(@"Error setting up compressor: %@", [error localizedDescription]);
    } else {
        AudioUnitSetParameter(compressor.audioUnit,
                              kDynamicsProcessorParam_Threshold,
                              kAudioUnitScope_Global,
                              0,
                              -5.0f, // -40->20
                              0);
        
        AudioUnitSetParameter(compressor.audioUnit,
                              kDynamicsProcessorParam_ExpansionRatio,
                              kAudioUnitScope_Global,
                              0,
                              7.0f, // 1->50.0
                              0);
        AudioUnitSetParameter(compressor.audioUnit,
                              kDynamicsProcessorParam_AttackTime,
                              kAudioUnitScope_Global,
                              0,
                              0.2f, // 0.0001->0.2
                              0);
        AudioUnitSetParameter(compressor.audioUnit,
                              kDynamicsProcessorParam_ReleaseTime,
                              kAudioUnitScope_Global,
                              0,
                              3.0f, // 0.01->3
                              0);
    }
    
    return compressor;
}

-(AEAudioUnitFilter*)addLimiter
{
    AudioComponentDescription component = AEAudioComponentDescriptionMake
    (kAudioUnitManufacturer_Apple,kAudioUnitType_Effect,kAudioUnitSubType_PeakLimiter);
    
    
    NSError *error = NULL;
    AEAudioUnitFilter *limiter = [[AEAudioUnitFilter alloc]
                                  initWithComponentDescription:component
                                  audioController:_audioController
                                  error:&error];
    if (!limiter) {
        NSLog(@"Error setting up limiter : %@", [error localizedDescription]);
    }
    
    return limiter;
}

@end
