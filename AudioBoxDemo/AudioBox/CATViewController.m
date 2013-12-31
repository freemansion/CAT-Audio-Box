//
//  RCGViewController.m
//  audioRecorder
//
//  Created by carl taylor on 30/12/2013.
//  Copyright (c) 2013 Carl Taylor. All rights reserved.
//

#import "CATViewController.h"
#import "CATAudioBox.h"

@interface CATViewController () <CATAudioBoxProtocol>

@property (nonatomic, strong) CATAudioBox *audioBox;

@property (weak, nonatomic) IBOutlet UIStepper *stepper;

@property (weak, nonatomic) IBOutlet UILabel *trackNumberLabel;

@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *buttonGroup;
 
@end

@implementation CATViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initializeAudioBox];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)initializeAudioBox
{
    self.audioBox = [[CATAudioBox alloc]initWithNumberOfRecordingSlots:10 andRecordingFormat:CATAUDIO_CONTROLLER_FORMAT_AIFF];
    self.audioBox.maxRecordingTime = @5;
    self.audioBox.delegate = self;
}

#pragma mark - On Screen Events

- (IBAction)record:(id)sender
{
    if (!self.audioBox) {
        [self initializeAudioBox];
    }
    
    BOOL slotNowRecording = [self.audioBox recordAudioForSlotNumber:self.stepper.value];
    if (slotNowRecording) {
        [self hideButtons];
    } else {
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error" message:@"Slot not available - reinitialise with more slots" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
}
- (IBAction)play:(id)sender
{
   [self.audioBox playAudioForSlotNumber:self.stepper.value];
}
- (IBAction)stop:(id)sender
{
    [self stopAudio];
}

- (IBAction)getAllFiles:(id)sender
{
    NSDictionary *audioFilesDict = [self.audioBox getAllRecordedFiles];
    NSLog(@"Numer of audio files in dict: %lu", (unsigned long)audioFilesDict.count);
    
    [self.audioBox cleanUpTempAudioFiles];
    self.audioBox = nil;
}

- (IBAction)stepperValueChanged:(id)sender
{
    int stepperVale = self.stepper.value;
    self.trackNumberLabel.text = [NSString stringWithFormat:@"%i",stepperVale];
    [self showButtons];
}

-(void)stopAudio
{
    [self.audioBox stopAudio];
}

-(void)hideButtons
{
    for (UIButton *button in self.buttonGroup) {
        button.hidden = YES;
    }
}

-(void)showButtons
{
    for (UIButton *button in self.buttonGroup) {
        button.hidden = NO;
    }
}

#pragma mark - Delegates

-(void)CATAudioBoxDidFinishPlaying
{
    NSLog(@"Did Finish Playing");
    [self showButtons];
}

-(void)CATAudioBoxDidFinishRecording
{
    NSLog(@"Did Finish Recording");
    [self showButtons];
}

@end
