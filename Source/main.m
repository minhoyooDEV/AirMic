#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <dlfcn.h>
#import "Localization.h"

// Public macOS 14 API, declared here so the existing Command Line Tools SDK can build it.
@protocol AudioApplicationAPI
+ (id<AudioApplicationAPI>)sharedInstance;
- (BOOL)setInputMuteStateChangeHandler:(BOOL (^)(BOOL))handler error:(NSError **)error;
- (BOOL)setInputMuted:(BOOL)muted error:(NSError **)error;
- (BOOL)isInputMuted;
@end

static AudioDeviceID inputDevice(void) {
    AudioDeviceID d=0; UInt32 n=sizeof(d);
    AudioObjectPropertyAddress p={kAudioHardwarePropertyDefaultInputDevice,kAudioObjectPropertyScopeGlobal,0};
    return AudioObjectGetPropertyData(kAudioObjectSystemObject,&p,0,NULL,&n,&d)==noErr?d:0;
}
static NSString *deviceString(AudioDeviceID d, AudioObjectPropertySelector selector) {
    CFStringRef s=NULL; UInt32 n=sizeof(s);
    AudioObjectPropertyAddress p={selector,kAudioObjectPropertyScopeGlobal,0};
    if(AudioObjectGetPropertyData(d,&p,0,NULL,&n,&s)!=noErr) return @"";
    return CFBridgingRelease(s) ?: @"";
}
static BOOL readMute(AudioDeviceID d, BOOL *muted) {
    UInt32 v=0,n=sizeof(v); Boolean writable=false;
    AudioObjectPropertyAddress p={kAudioDevicePropertyMute,kAudioDevicePropertyScopeInput,0};
    if(!d || AudioObjectIsPropertySettable(d,&p,&writable)!=noErr || !writable) return NO;
    if(AudioObjectGetPropertyData(d,&p,0,NULL,&n,&v)!=noErr) return NO;
    *muted=v!=0; return YES;
}
static BOOL writeMute(AudioDeviceID d, BOOL muted) {
    UInt32 v=muted?1:0;
    AudioObjectPropertyAddress p={kAudioDevicePropertyMute,kAudioDevicePropertyScopeInput,0};
    if(AudioObjectSetPropertyData(d,&p,0,NULL,sizeof(v),&v)!=noErr) return NO;
    BOOL actual=NO;
    return readMute(d,&actual) && actual==muted;
}
static OSStatus discardInput(void *context, AudioUnitRenderActionFlags *flags,
 const AudioTimeStamp *time, UInt32 bus, UInt32 frames, AudioBufferList *data) {
    // The input I/O remains active, but no audio buffers are read, stored, or forwarded.
    return noErr;
}

@interface Controller : NSObject
@property NSMutableDictionary *original;
@property NSUInteger gestures;
@property NSString *lastError;
- (BOOL)apply:(BOOL)muted;
- (NSArray *)restore;
@end
@implementation Controller
- (instancetype)init { if((self=[super init])) {
    self.original=[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"OriginalMuteStates"] mutableCopy] ?: [NSMutableDictionary dictionary];
    self.lastError=@"";
} return self; }
- (BOOL)apply:(BOOL)muted { @synchronized(self) {
    AudioDeviceID d=inputDevice(); BOOL prior=NO;
    NSString *uid=deviceString(d,kAudioDevicePropertyDeviceUID);
    if(!readMute(d,&prior) || uid.length==0) { self.lastError=L(@"error.unsupported_input"); return NO; }
    if(!self.original[uid]) {
        self.original[uid]=@(prior);
        [[NSUserDefaults standardUserDefaults] setObject:self.original forKey:@"OriginalMuteStates"];
    }
    if(!writeMute(d,muted)) {
        writeMute(d,prior);
        self.lastError=L(@"error.mute_verification"); return NO;
    }
    self.lastError=@""; return YES;
} }
- (NSArray *)restore { @synchronized(self) {
    NSMutableArray *failed=[NSMutableArray array];
    AudioObjectPropertyAddress p={kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,0}; UInt32 n=0;
    if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&p,0,NULL,&n)!=noErr) return @[L(@"error.device_list")];
    NSMutableData *data=[NSMutableData dataWithLength:n];
    if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&p,0,NULL,&n,data.mutableBytes)!=noErr) return @[L(@"error.device_list")];
    AudioDeviceID *devices=data.mutableBytes;
    for(UInt32 i=0;i<n/sizeof(AudioDeviceID);i++) {
        NSString *uid=deviceString(devices[i],kAudioDevicePropertyDeviceUID); NSNumber *prior=self.original[uid];
        if(!prior) continue;
        if(writeMute(devices[i],prior.boolValue)) [self.original removeObjectForKey:uid];
        else [failed addObject:deviceString(devices[i],kAudioObjectPropertyName)];
    }
    // Disconnected devices are retained for restoration on a later launch/quit.
    [[NSUserDefaults standardUserDefaults] setObject:self.original forKey:@"OriginalMuteStates"];
    return failed;
} }
@end

@interface App : NSObject <NSApplicationDelegate>
@property Controller *control;
@property id<AudioApplicationAPI> audioApp;
@property AudioUnit audioUnit;
@property NSStatusItem *status;
@property NSMenuItem *deviceLine,*stateLine,*toggleLine,*listenLine,*eventLine;
@property BOOL listening,requesting;
@property AudioDeviceID watchedDevice;
@property NSString *message;
@property NSWindow *window;
@property NSTextField *windowState,*windowDevice,*windowListening;
@property NSButton *windowToggle,*windowListen;
- (void)prepareWindow;
@end
@implementation App
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.control=[Controller new]; self.message=L(@"status.ready");
    dlopen("/System/Library/Frameworks/AVFAudio.framework/AVFAudio",RTLD_LAZY);
    Class cls=NSClassFromString(@"AVAudioApplication");
    self.audioApp=[(Class<AudioApplicationAPI>)cls sharedInstance];
    NSString * __unsafe_unretained *muteNotification=(NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT,"AVAudioApplicationInputMuteStateChangeNotification");
    if(muteNotification && *muteNotification) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(muteNotification:) name:*muteNotification object:nil];
    self.status=[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.status.button.target=self; self.status.button.action=@selector(clicked:);
    [self.status.button sendActionOn:NSEventMaskLeftMouseUp|NSEventMaskRightMouseUp];
    NSMenu *menu=[NSMenu new];
    self.deviceLine=[menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    self.stateLine=[menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    self.eventLine=[menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    self.toggleLine=[menu addItemWithTitle:L(@"action.toggle") action:@selector(toggle:) keyEquivalent:@""];
    self.listenLine=[menu addItemWithTitle:L(@"action.start_listening") action:@selector(changeListening:) keyEquivalent:@""];
    [menu addItemWithTitle:L(@"action.help") action:@selector(help:) keyEquivalent:@""];
    [menu addItemWithTitle:L(@"action.show_window") action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:L(@"action.quit_restore") action:@selector(quit:) keyEquivalent:@"q"];
    for(NSMenuItem *item in menu.itemArray) if(item.action) item.target=self;
    self.status.menu=menu;
    self.watchedDevice=inputDevice();
    [self showWindow:nil];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [self refresh];
    [self changeListening:nil];
}
- (void)clicked:(id)sender { [self toggle:nil]; }
- (void)refresh {
    AudioDeviceID d=inputDevice(); BOOL muted=NO; BOOL supported=readMute(d,&muted);
    if(d!=self.watchedDevice) {
        self.watchedDevice=d;
        if(self.listening) { [self stop]; [self startEngine]; }
    }
    self.deviceLine.title=[NSString stringWithFormat:L(@"device.input"),deviceString(d,kAudioObjectPropertyName)];
    self.stateLine.title=supported?(muted?L(@"state.muted"):L(@"state.unmuted")):L(@"state.unsupported");
    self.status.button.image=[NSImage imageWithSystemSymbolName:supported?(muted?@"mic.slash.fill":@"mic.fill"):@"exclamationmark.triangle" accessibilityDescription:self.stateLine.title];
    self.status.button.toolTip=[NSString stringWithFormat:@"AirMic · %@\n%@",self.stateLine.title,self.message];
    self.eventLine.title=self.listening?[NSString stringWithFormat:L(@"status.events"),(unsigned long)self.control.gestures]:self.message;
    self.listenLine.title=self.listening?L(@"action.stop_listening"):L(@"action.start_listening");
    self.toggleLine.enabled=supported;
    self.toggleLine.title=muted?L(@"action.unmute"):L(@"action.mute");
    self.windowState.stringValue=self.stateLine.title;
    self.windowDevice.stringValue=self.deviceLine.title;
    self.windowListening.stringValue=self.control.lastError.length?self.control.lastError:(self.listening?L(@"status.listening"):self.message);
    self.windowToggle.title=self.toggleLine.title; self.windowToggle.enabled=supported;
    self.windowListen.title=self.listenLine.title;
}
- (NSTextField *)label:(NSString *)text size:(CGFloat)size {
    NSTextField *label=[NSTextField wrappingLabelWithString:text];
    label.font=[NSFont systemFontOfSize:size];
    label.alignment=NSTextAlignmentCenter;
    label.maximumNumberOfLines=0;
    return label;
}
- (void)prepareWindow {
    if(!self.window) {
        self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,480,330) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
        self.window.contentMinSize=NSMakeSize(480,330);
        self.window.title=@"AirMic"; self.window.releasedWhenClosed=NO; [self.window center];
        self.windowState=[self label:L(@"state.checking") size:24];
        self.windowDevice=[self label:@"" size:13];
        self.windowListening=[self label:@"" size:12];
        self.windowToggle=[NSButton buttonWithTitle:L(@"action.toggle") target:self action:@selector(toggle:)];
        self.windowListen=[NSButton buttonWithTitle:L(@"action.start_listening") target:self action:@selector(changeListening:)];
        NSTextField *privacy=[self label:L(@"privacy.summary") size:11];
        NSArray<NSView *> *views=@[self.windowState,self.windowDevice,self.windowListening,self.windowToggle,self.windowListen,privacy];
        NSStackView *stack=[NSStackView stackViewWithViews:views];
        stack.orientation=NSUserInterfaceLayoutOrientationVertical;
        stack.alignment=NSLayoutAttributeCenterX;
        stack.spacing=14;
        stack.translatesAutoresizingMaskIntoConstraints=NO;
        [self.window.contentView addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:24],
            [stack.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-24],
            [stack.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:24],
            [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.window.contentView.bottomAnchor constant:-24]
        ]];
        for(NSView *view in views) {
            view.translatesAutoresizingMaskIntoConstraints=NO;
            if([view isKindOfClass:[NSTextField class]]) {
                [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
            } else {
                [view.widthAnchor constraintGreaterThanOrEqualToConstant:240].active=YES;
                [view.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor].active=YES;
            }
        }
    }
}
- (void)showWindow:(id)sender {
    [self prepareWindow];
    [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)toggle:(id)sender {
    BOOL muted=NO;
    if(!readMute(inputDevice(),&muted)) return;
    BOOL ok=[self.control apply:!muted];
    // Synchronize the public app state without counting a menu action as a stem press.
    if(ok && self.audioApp) {
        [self.audioApp setInputMuteStateChangeHandler:nil error:NULL];
        [self.audioApp setInputMuted:!muted error:NULL];
        if(self.listening) [self registerHandler];
    }
    self.message=ok?L(@"status.changed"):self.control.lastError;
    if(!ok) NSBeep(); [self refresh];
}
- (BOOL)registerHandler {
    Controller *control=self.control; NSError *error=nil;
    BOOL ok=[self.audioApp setInputMuteStateChangeHandler:^BOOL(BOOL muted) {
        @synchronized(control) { control.gestures++; }
        BOOL result=[control apply:muted];
        return result;
    } error:&error];
    if(!ok) self.message=error.localizedDescription ?: L(@"error.handler");
    return ok;
}
- (void)startEngine {
    if(!self.audioApp) { self.message=L(@"error.os_version"); [self refresh]; return; }
    BOOL muted=NO;
    if(!readMute(inputDevice(),&muted)) { self.message=L(@"error.current_input"); return; }
    [self.audioApp setInputMuted:muted error:NULL];
    if(![self registerHandler]) return;
    AudioComponentDescription desc={kAudioUnitType_Output,kAudioUnitSubType_HALOutput,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent component=AudioComponentFindNext(NULL,&desc); AudioUnit unit=NULL;
    OSStatus result=component?AudioComponentInstanceNew(component,&unit):-1;
    UInt32 on=1,off=0; AudioDeviceID d=inputDevice();
    if(result==noErr) result=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Input,1,&on,sizeof(on));
    if(result==noErr) result=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Output,0,&off,sizeof(off));
    if(result==noErr) result=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&d,sizeof(d));
    AURenderCallbackStruct callback={discardInput,NULL};
    if(result==noErr) result=AudioUnitSetProperty(unit,kAudioOutputUnitProperty_SetInputCallback,kAudioUnitScope_Global,0,&callback,sizeof(callback));
    if(result==noErr) result=AudioUnitInitialize(unit);
    if(result==noErr) result=AudioOutputUnitStart(unit);
    if(result==noErr) { self.audioUnit=unit; self.listening=YES; self.message=L(@"status.detecting"); }
    else {
        if(unit) { AudioOutputUnitStop(unit); AudioComponentInstanceDispose(unit); }
        [self.audioApp setInputMuteStateChangeHandler:nil error:NULL];
        self.message=[NSString stringWithFormat:L(@"error.input_start"),(int)result];
    }
    [self refresh];
}
- (void)changeListening:(id)sender {
    if(self.listening) { [self stop]; self.message=L(@"status.stopped"); [self refresh]; return; }
    if(self.requesting) return;
    self.requesting=YES;
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(),^{
            self.requesting=NO;
            if(granted) [self startEngine];
            else { self.message=L(@"error.permission"); [self refresh]; }
        });
    }];
}
- (void)muteNotification:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(),^{ [self refresh]; });
}
- (void)stop {
    self.listening=NO;
    [self.audioApp setInputMuteStateChangeHandler:nil error:NULL];
    if(self.audioUnit) {
        AudioOutputUnitStop(self.audioUnit); AudioUnitUninitialize(self.audioUnit);
        AudioComponentInstanceDispose(self.audioUnit); self.audioUnit=NULL;
    }
}
- (void)help:(id)sender {
    NSAlert *a=[NSAlert new]; a.messageText=@"AirMic";
    a.informativeText=L(@"help.body");
    [a addButtonWithTitle:L(@"action.ok")]; [NSApp activateIgnoringOtherApps:YES]; [a runModal];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [self stop]; NSArray *failed=[self.control restore];
    if(failed.count) {
        NSAlert *a=[NSAlert new]; a.messageText=L(@"error.restore_title");
        a.informativeText=[failed componentsJoinedByString:@", "];
        [a addButtonWithTitle:L(@"action.cancel_quit")]; [a addButtonWithTitle:L(@"action.quit_anyway")];
        if([a runModal]==NSAlertFirstButtonReturn) { [self refresh]; return NSTerminateCancel; }
    }
    return NSTerminateNow;
}
@end

static void printUsage(FILE *stream) {
    fprintf(stream, "Usage: AirMic [--help | --version | --check | --self-test]\n"
            "  No arguments  Open the menu bar app and request microphone access.\n"
            "  --help        Show this help without accessing audio hardware.\n"
            "  --version     Show the bundle version without accessing audio hardware.\n"
            "  --check       Read the default input's mute capability and state.\n"
            "  --self-test   Flip real hardware mute, then attempt to restore it.\n"
            "                Run only outside calls and recordings.\n");
}

int main(int argc,const char *argv[]) { @autoreleasepool {
    if(argc>2) { printUsage(stderr); return 64; }
    if(argc==2 && strcmp(argv[1],"--help")==0) { printUsage(stdout); return 0; }
    if(argc==2 && strcmp(argv[1],"--version")==0) {
        NSString *version=[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        printf("AirMic %s\n",(version ?: @"unknown").UTF8String);
        return version ? 0 : 1;
    }
    if(argc>1 && strcmp(argv[1],"--check")==0) {
        BOOL mute=NO; AudioDeviceID d=inputDevice(); BOOL supported=readMute(d,&mute);
        printf("device=%s supported=%d muted=%d\n",deviceString(d,kAudioObjectPropertyName).UTF8String,supported,mute);
        return supported?0:1;
    }
    if(argc>1 && strcmp(argv[1],"--self-test")==0) {
        BOOL prior=NO; AudioDeviceID d=inputDevice(); if(!readMute(d,&prior)) return 1;
        BOOL changed=writeMute(d,!prior); BOOL restored=writeMute(d,prior); BOOL end=NO;
        BOOL verified=readMute(d,&end)&&end==prior;
        printf("toggle=%d restore=%d verified=%d\n",changed,restored,verified);
        return changed&&restored&&verified?0:1;
    }
    if(argc>1) { fprintf(stderr,"Unknown option: %s\n",argv[1]); printUsage(stderr); return 64; }
    NSApplication *app=[NSApplication sharedApplication];
    App *delegate=[App new]; app.delegate=delegate;
    [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; [app run];
} return 0; }
