#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <dlfcn.h>

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
    if(!readMute(d,&prior) || uid.length==0) { self.lastError=@"이 마이크는 음소거 제어를 지원하지 않습니다."; return NO; }
    if(!self.original[uid]) {
        self.original[uid]=@(prior);
        [[NSUserDefaults standardUserDefaults] setObject:self.original forKey:@"OriginalMuteStates"];
    }
    if(!writeMute(d,muted)) {
        writeMute(d,prior);
        self.lastError=@"마이크 상태 변경을 확인하지 못했습니다."; return NO;
    }
    self.lastError=@""; return YES;
} }
- (NSArray *)restore { @synchronized(self) {
    NSMutableArray *failed=[NSMutableArray array];
    AudioObjectPropertyAddress p={kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,0}; UInt32 n=0;
    if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&p,0,NULL,&n)!=noErr) return @[@"장치 목록 조회 실패"];
    NSMutableData *data=[NSMutableData dataWithLength:n];
    if(AudioObjectGetPropertyData(kAudioObjectSystemObject,&p,0,NULL,&n,data.mutableBytes)!=noErr) return @[@"장치 목록 조회 실패"];
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
@end
@implementation App
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.control=[Controller new]; self.message=@"버튼 감지를 시작하세요.";
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
    self.toggleLine=[menu addItemWithTitle:@"마이크 켜기 / 끄기" action:@selector(toggle:) keyEquivalent:@""];
    self.listenLine=[menu addItemWithTitle:@"AirPods 버튼 감지 시작" action:@selector(changeListening:) keyEquivalent:@""];
    [menu addItemWithTitle:@"사용 방법" action:@selector(help:) keyEquivalent:@""];
    [menu addItemWithTitle:@"상태 창 열기" action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"종료 (원래 마이크 상태 복원)" action:@selector(quit:) keyEquivalent:@"q"];
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
    self.deviceLine.title=[@"입력: " stringByAppendingString:deviceString(d,kAudioObjectPropertyName)];
    self.stateLine.title=supported?(muted?@"마이크 꺼짐":@"마이크 켜짐"):@"음소거 제어 불가";
    self.status.button.image=[NSImage imageWithSystemSymbolName:supported?(muted?@"mic.slash.fill":@"mic.fill"):@"exclamationmark.triangle" accessibilityDescription:self.stateLine.title];
    self.status.button.toolTip=[NSString stringWithFormat:@"AirMic · %@\n%@",self.stateLine.title,self.message];
    self.eventLine.title=self.listening?[NSString stringWithFormat:@"버튼 감지 중 · 수신 %lu회",(unsigned long)self.control.gestures]:self.message;
    self.listenLine.title=self.listening?@"AirPods 버튼 감지 중지":@"AirPods 버튼 감지 시작";
    self.toggleLine.enabled=supported;
    self.toggleLine.title=muted?@"마이크 켜기":@"마이크 끄기";
    self.windowState.stringValue=self.stateLine.title;
    self.windowDevice.stringValue=self.deviceLine.title;
    self.windowListening.stringValue=self.control.lastError.length?self.control.lastError:(self.listening?@"AirPods 버튼 감지 중":self.message);
    self.windowToggle.title=self.toggleLine.title; self.windowToggle.enabled=supported;
    self.windowListen.title=self.listenLine.title;
}
- (NSTextField *)label:(NSString *)text y:(CGFloat)y size:(CGFloat)size {
    NSTextField *label=[NSTextField labelWithString:text];
    label.frame=NSMakeRect(24,y,372,30); label.font=[NSFont systemFontOfSize:size];
    label.alignment=NSTextAlignmentCenter; [self.window.contentView addSubview:label]; return label;
}
- (void)showWindow:(id)sender {
    if(!self.window) {
        self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,420,265) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
        self.window.title=@"AirMic"; self.window.releasedWhenClosed=NO; [self.window center];
        self.windowState=[self label:@"마이크 상태 확인 중" y:205 size:24];
        self.windowDevice=[self label:@"" y:165 size:13];
        self.windowListening=[self label:@"" y:135 size:12];
        self.windowToggle=[NSButton buttonWithTitle:@"마이크 켜기 / 끄기" target:self action:@selector(toggle:)];
        self.windowToggle.frame=NSMakeRect(110,90,200,32); [self.window.contentView addSubview:self.windowToggle];
        self.windowListen=[NSButton buttonWithTitle:@"AirPods 버튼 감지 시작" target:self action:@selector(changeListening:)];
        self.windowListen.frame=NSMakeRect(85,50,250,32); [self.window.contentView addSubview:self.windowListen];
        [self label:@"소리는 저장하거나 전송하지 않습니다." y:12 size:11];
    }
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
    self.message=ok?@"마이크 상태를 변경했습니다.":self.control.lastError;
    if(!ok) NSBeep(); [self refresh];
}
- (BOOL)registerHandler {
    Controller *control=self.control; NSError *error=nil;
    BOOL ok=[self.audioApp setInputMuteStateChangeHandler:^BOOL(BOOL muted) {
        @synchronized(control) { control.gestures++; }
        BOOL result=[control apply:muted];
        return result;
    } error:&error];
    if(!ok) self.message=error.localizedDescription ?: @"버튼 감지를 등록하지 못했습니다.";
    return ok;
}
- (void)startEngine {
    if(!self.audioApp) { self.message=@"macOS 14 이상이 필요합니다."; [self refresh]; return; }
    BOOL muted=NO;
    if(!readMute(inputDevice(),&muted)) { self.message=@"현재 마이크는 음소거 제어를 지원하지 않습니다."; return; }
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
    if(result==noErr) { self.audioUnit=unit; self.listening=YES; self.message=@"버튼 감지 중"; }
    else {
        if(unit) { AudioOutputUnitStop(unit); AudioComponentInstanceDispose(unit); }
        [self.audioApp setInputMuteStateChangeHandler:nil error:NULL];
        self.message=[NSString stringWithFormat:@"마이크 입력 시작 실패 (%d)",(int)result];
    }
    [self refresh];
}
- (void)changeListening:(id)sender {
    if(self.listening) { [self stop]; self.message=@"버튼 감지 중지됨"; [self refresh]; return; }
    if(self.requesting) return;
    self.requesting=YES;
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(),^{
            self.requesting=NO;
            if(granted) [self startEngine];
            else { self.message=@"시스템 설정에서 AirMic 마이크 접근을 허용해 주세요."; [self refresh]; }
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
    a.informativeText=@"메뉴 막대의 마이크 아이콘에서 ‘AirPods 버튼 감지 시작’을 선택하세요. 마이크 접근을 허용한 뒤 AirPods 줄기를 한 번 누르면 현재 기본 입력 마이크가 음소거/해제됩니다.\n\n이 마이크를 쓰는 다른 앱에도 적용됩니다. 다른 입력 장치는 제어하지 않습니다. 버튼 감지 중에는 마이크 표시가 켜질 수 있고 Bluetooth 음질·배터리에 영향을 줄 수 있습니다. 오디오는 저장하거나 전송하지 않습니다.\n\n메뉴에서도 마이크를 켜고 끌 수 있습니다. 정상 종료하면 변경 전 마이크 상태로 복원합니다. 다른 통화 앱이 AirPods 버튼을 처리하면 충돌할 수 있습니다.";
    [a addButtonWithTitle:@"확인"]; [NSApp activateIgnoringOtherApps:YES]; [a runModal];
}
- (void)quit:(id)sender { [NSApp terminate:nil]; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [self stop]; NSArray *failed=[self.control restore];
    if(failed.count) {
        NSAlert *a=[NSAlert new]; a.messageText=@"마이크 상태 복원 실패";
        a.informativeText=[failed componentsJoinedByString:@", "];
        [a addButtonWithTitle:@"종료 취소"]; [a addButtonWithTitle:@"그대로 종료"];
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
