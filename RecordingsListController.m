#import "RecordingsListController.h"
#import "AgoraRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface RecordingsListController () <AVAudioPlayerDelegate>
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSArray<NSString *> *paths;
@end

@implementation RecordingsListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        self.paths = [[AgoraRecorder sharedRecorder] allRecordings];

        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier preferenceSpecifierNamed:@"Recordings"
                                                              target:self
                                                                 set:nil
                                                                 get:nil
                                                             detail:nil
                                                                cell:PSGroupCell
                                                                edit:nil];
        [specs addObject:group];

        if (self.paths.count == 0) {
            PSSpecifier *empty = [PSSpecifier preferenceSpecifierNamed:@"No recordings yet"
                                                                  target:self
                                                                     set:nil
                                                                     get:nil
                                                                 detail:nil
                                                                    cell:PSStaticTextCell
                                                                    edit:nil];
            [specs addObject:empty];
        }

        for (NSString *path in self.paths) {
            NSString *displayName = [path lastPathComponent];
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:displayName
                                                                 target:self
                                                                    set:nil
                                                                    get:nil
                                                                detail:nil
                                                                   cell:PSButtonCell
                                                                   edit:nil];
            spec.buttonAction = @selector(playRecording:);
            [spec setProperty:path forKey:@"filePath"];
            [specs addObject:spec];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)playRecording:(PSSpecifier *)specifier {
    NSString *path = [specifier propertyForKey:@"filePath"];
    if (!path) return;

    NSError *error;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
    self.player.delegate = self;

    if (error) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Playback error"
                                                                         message:error.localizedDescription
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[path lastPathComponent]
                                                                     message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Play" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self.player play];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Upload to Twilio" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[AgoraRecorder sharedRecorder] uploadRecordingAtPath:path completion:^(BOOL success, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *msg = success ? @"Upload complete." : [NSString stringWithFormat:@"Upload failed: %@", err.localizedDescription];
                UIAlertController *result = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
                [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:result animated:YES completion:nil];
            });
        }];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[AgoraRecorder sharedRecorder] deleteRecordingAtPath:path];
        self.specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
