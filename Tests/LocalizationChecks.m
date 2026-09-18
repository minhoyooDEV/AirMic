// Exercise the real bundle and window code without installing a delegate,
// constructing Controller, requesting permission, or starting audio I/O.
#define main AirMicApplicationMain
#import "../Source/main.m"
#undef main

static void require(BOOL condition, NSString *message) {
    if(!condition) { fprintf(stderr,"FAIL: %s\n",message.UTF8String); exit(1); }
}

static NSDictionary *table(NSString *language, NSString *name) {
    NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:
                    [NSString stringWithFormat:@"%@.lproj/%@.strings",language,name]];
    NSDictionary *values=[NSDictionary dictionaryWithContentsOfFile:path];
    require(values.count>0,[NSString stringWithFormat:@"Missing table: %@",path]);
    return values;
}

static NSArray *formats(NSString *value) {
    NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"%(?:lu|d|@|%)" options:0 error:NULL];
    NSString *withoutTokens=[pattern stringByReplacingMatchesInString:value options:0 range:NSMakeRange(0,value.length) withTemplate:@""];
    require(![withoutTokens containsString:@"%"],@"Unsupported format token (use %@, %lu, %d, or %%)");
    NSMutableArray *result=[NSMutableArray array];
    for(NSTextCheckingResult *match in [pattern matchesInString:value options:0 range:NSMakeRange(0,value.length)]) {
        [result addObject:[value substringWithRange:match.range]];
    }
    return result;
}

static void checkLayout(App *subject, NSDictionary *strings) {
    subject.windowDevice.stringValue=[NSString stringWithFormat:L(@"device.input"),@"AirPods Pro"];
    subject.windowState.stringValue=L(@"state.unsupported");
    NSArray *statusKeys=@[@"status.ready",@"status.listening",@"status.stopped",@"error.permission",@"error.current_input",@"error.mute_verification"];
    for(NSString *key in statusKeys) {
        subject.windowListening.stringValue=strings[key];
        [subject.window.contentView layoutSubtreeIfNeeded];
        NSStackView *stack=(NSStackView *)subject.window.contentView.subviews.firstObject;
        require(NSContainsRect(subject.window.contentView.bounds,stack.frame),@"Stack exceeds the content area");
        for(NSView *view in stack.arrangedSubviews) {
            NSRect frame=[view convertRect:view.bounds toView:subject.window.contentView];
            require(NSContainsRect(subject.window.contentView.bounds,frame),@"Localized control is outside the window");
            if([view isKindOfClass:NSTextField.class]) {
                NSTextField *label=(NSTextField *)view;
                NSRect bounds=[label.stringValue boundingRectWithSize:NSMakeSize(label.bounds.size.width,CGFLOAT_MAX)
                         options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading
                         attributes:@{NSFontAttributeName:label.font}];
                require(NSHeight(label.bounds)+2>=ceil(NSHeight(bounds)),[NSString stringWithFormat:@"Clipped label: %@",label.stringValue]);
            } else {
                require(view.frame.size.width+1>=view.intrinsicContentSize.width,@"Clipped button title");
            }
        }
    }
}

int main(int argc, const char *argv[]) { @autoreleasepool {
    NSString *expected=[NSUserDefaults.standardUserDefaults stringForKey:@"ExpectedLanguage"];
    require(expected.length>0,@"Pass -ExpectedLanguage en or ko");
    NSBundle *bundle=NSBundle.mainBundle;
    NSDictionary *english=table(@"en",@"Localizable");
    NSSet *keys=[NSSet setWithArray:english.allKeys];
    for(NSString *language in bundle.localizations) {
        NSDictionary *translated=table(language,@"Localizable");
        require([keys isEqualToSet:[NSSet setWithArray:translated.allKeys]],@"Localization keys differ");
        for(NSString *key in keys) {
            require([translated[key] isKindOfClass:NSString.class] && [translated[key] length]>0,@"Empty translation");
            require([formats(english[key]) isEqualToArray:formats(translated[key])],[NSString stringWithFormat:@"Format mismatch: %@",key]);
        }
        require([table(language,@"InfoPlist")[@"NSMicrophoneUsageDescription"] length]>0,@"Missing localized permission purpose");
    }
    require([bundle.preferredLocalizations.firstObject isEqualToString:expected],@"Wrong language selection/fallback");
    NSDictionary *selected=table(expected,@"Localizable");
    for(NSString *key in keys) {
        require([L(key) isEqualToString:selected[key]],[NSString stringWithFormat:@"Unresolved translation: %@",key]);
    }
    require([[bundle objectForInfoDictionaryKey:@"NSMicrophoneUsageDescription"] isEqualToString:table(expected,@"InfoPlist")[@"NSMicrophoneUsageDescription"]],@"Permission purpose did not localize");

    // Check every literal key used by production code against the resources.
    NSString *sourcePath=[NSUserDefaults.standardUserDefaults stringForKey:@"SourcePath"];
    NSString *source=[NSString stringWithContentsOfFile:sourcePath encoding:NSUTF8StringEncoding error:NULL];
    require(source.length>0,@"Missing production source for key validation");
    NSRegularExpression *keyPattern=[NSRegularExpression regularExpressionWithPattern:@"L\\(@\"([^\"]+)\"\\)" options:0 error:NULL];
    for(NSTextCheckingResult *match in [keyPattern matchesInString:source options:0 range:NSMakeRange(0,source.length)]) {
        NSString *key=[source substringWithRange:[match rangeAtIndex:1]];
        require([keys containsObject:key],[NSString stringWithFormat:@"Missing source key: %@",key]);
    }
    NSRegularExpression *korean=[NSRegularExpression regularExpressionWithPattern:@"[가-힣]" options:0 error:NULL];
    require([korean numberOfMatchesInString:source options:0 range:NSMakeRange(0,source.length)]==0,@"Hard-coded Korean remains in production source");

    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    App *subject=[App new];
    [subject prepareWindow];
    checkLayout(subject,selected);
    // Verify both dynamic button titles as well as initial ones.
    subject.windowToggle.title=L(@"action.unmute");
    subject.windowListen.title=L(@"action.stop_listening");
    checkLayout(subject,selected);
    printf("PASS: language=%s, %lu keys, format placeholders, permission purpose, and window layout. No audio I/O.\n",expected.UTF8String,(unsigned long)keys.count);

    // Optional developer preview: read-only controls and no audio lifecycle.
    if([NSUserDefaults.standardUserDefaults boolForKey:@"ShowPreview"]) {
        subject.windowState.stringValue=L(@"state.muted");
        subject.windowListening.stringValue=L(@"status.listening");
        subject.windowToggle.enabled=NO; subject.windowListen.enabled=NO;
        [subject showWindow:nil];
        [NSApp run];
    }
    return 0;
} }
