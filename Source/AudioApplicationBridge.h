#import <Foundation/Foundation.h>
#import <dlfcn.h>

// SDK compatibility only: the public macOS 14 API is resolved at runtime so
// standalone Command Line Tools with an older SDK can still build the app.
// All application, UI, audio-device, and restoration logic lives in Swift.
@protocol AMAudioApplication
+ (id)sharedInstance;
- (BOOL)setInputMuteStateChangeHandler:(BOOL (^ _Nullable)(BOOL))handler error:(NSError **)error;
- (BOOL)setInputMuted:(BOOL)muted error:(NSError **)error;
@end

static inline NSObject * _Nullable AMSharedAudioApplication(void) {
    dlopen("/System/Library/Frameworks/AVFAudio.framework/AVFAudio", RTLD_LAZY);
    Class cls = NSClassFromString(@"AVAudioApplication");
    return [(Class<AMAudioApplication>)cls sharedInstance];
}
static inline BOOL AMSetMuteHandler(NSObject * _Nonnull app, BOOL (^ _Nullable handler)(BOOL)) {
    return [(id<AMAudioApplication>)app setInputMuteStateChangeHandler:handler error:NULL];
}
static inline BOOL AMSetInputMuted(NSObject * _Nonnull app, BOOL muted) {
    return [(id<AMAudioApplication>)app setInputMuted:muted error:NULL];
}
static inline NSString * _Nullable AMMuteNotificationName(void) {
    NSString * __unsafe_unretained *name = (NSString * __unsafe_unretained *)dlsym(RTLD_DEFAULT, "AVAudioApplicationInputMuteStateChangeNotification");
    return name ? *name : nil;
}
