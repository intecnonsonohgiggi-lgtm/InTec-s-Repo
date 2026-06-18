// ==============================================================================
//  SiriAIOverhaul — Tweak.x
//  Logos / Objective-C — iOS 15+ Rootless (Dopamine) — Apple A9 arm64
// ==============================================================================

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <Speech/Speech.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <substrate.h>

static NSString *const kPrefsPath     = @"/var/jb/var/mobile/Library/Preferences/com.tuonome.siriaioverhaul.plist";
static NSString *const kHerySiriStart = @"com.tuonome.siriaioverhaul.heySiriStart";
static NSString *const kHerySiriStop  = @"com.tuonome.siriaioverhaul.heySiriStop";
static const CGFloat        kBorderW  = 6.0f;
static const CFTimeInterval kGlowDur  = 2.8;

// ==============================================================================
#pragma mark - Preferenze
// ==============================================================================

typedef NS_ENUM(NSInteger, SAOProvider) {
    SAOProviderGPT    = 0,
    SAOProviderGemini = 1
};

static NSDictionary *SAOPrefs(void) {
    return [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ?: @{};
}
static NSString   *SAOKey(void)         { return SAOPrefs()[@"apiKey"] ?: @""; }
static SAOProvider SAOGetProvider(void) { return (SAOProvider)[SAOPrefs()[@"aiProvider"] integerValue]; }
static BOOL        SAOEnabled(void)     { NSNumber *v = SAOPrefs()[@"enabled"];     return v ? v.boolValue : YES; }
static BOOL        SAOGlowOn(void)      { NSNumber *v = SAOPrefs()[@"glowEnabled"]; return v ? v.boolValue : YES; }

// ==============================================================================
#pragma mark - SAOGlowView
// ==============================================================================

@interface SAOGlowView : UIView
- (void)startGlow;
- (void)stopGlow;
@end

@implementation SAOGlowView {
    CAShapeLayer *_top, *_bot, *_lft, *_rgt;
    BOOL _glowing;
}

- (instancetype)initWithFrame:(CGRect)f {
    self = [super initWithFrame:f];
    if (!self) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor clearColor];
    _top = [self _makeLayer:UIRectEdgeTop    frame:f];
    _bot = [self _makeLayer:UIRectEdgeBottom frame:f];
    _lft = [self _makeLayer:UIRectEdgeLeft   frame:f];
    _rgt = [self _makeLayer:UIRectEdgeRight  frame:f];
    [self.layer addSublayer:_top];
    [self.layer addSublayer:_bot];
    [self.layer addSublayer:_lft];
    [self.layer addSublayer:_rgt];
    return self;
}

- (CAShapeLayer *)_makeLayer:(UIRectEdge)edge frame:(CGRect)f {
    CAShapeLayer *l = [CAShapeLayer layer];
    l.fillColor = nil;
    l.lineWidth = kBorderW;
    l.opacity   = 0.f;
    CGFloat w = f.size.width, h = f.size.height, hw = kBorderW / 2.f;
    UIBezierPath *p = [UIBezierPath bezierPath];
    if (edge == UIRectEdgeTop)    { [p moveToPoint:CGPointMake(0,hw)];   [p addLineToPoint:CGPointMake(w,hw)]; }
    if (edge == UIRectEdgeBottom) { [p moveToPoint:CGPointMake(0,h-hw)]; [p addLineToPoint:CGPointMake(w,h-hw)]; }
    if (edge == UIRectEdgeLeft)   { [p moveToPoint:CGPointMake(hw,0)];   [p addLineToPoint:CGPointMake(hw,h)]; }
    if (edge == UIRectEdgeRight)  { [p moveToPoint:CGPointMake(w-hw,0)]; [p addLineToPoint:CGPointMake(w-hw,h)]; }
    l.path = p.CGPath;
    return l;
}

- (void)startGlow {
    if (_glowing || !SAOGlowOn()) return;
    _glowing = YES;
    NSArray *colors = @[
        (__bridge id)[UIColor colorWithRed:0.40 green:0.60 blue:1.00 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.70 green:0.40 blue:1.00 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:1.00 green:0.45 blue:0.70 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.40 green:0.85 blue:0.75 alpha:1].CGColor,
        (__bridge id)[UIColor colorWithRed:0.40 green:0.60 blue:1.00 alpha:1].CGColor,
    ];
    NSArray *kt     = @[@0.0, @0.25, @0.50, @0.75, @1.0];
    NSArray *layers = @[_top, _bot, _lft, _rgt];
    double   offs[] = {0.0, 0.5, 0.25, 0.75};

    for (NSUInteger i = 0; i < 4; i++) {
        CAShapeLayer *layer = layers[i];

        CAKeyframeAnimation *ca = [CAKeyframeAnimation animationWithKeyPath:@"strokeColor"];
        ca.values = colors; ca.keyTimes = kt; ca.duration = kGlowDur;
        ca.repeatCount = HUGE_VALF; ca.calculationMode = kCAAnimationLinear;
        ca.fillMode = kCAFillModeForwards; ca.removedOnCompletion = NO;
        ca.timeOffset = offs[i] * kGlowDur;

        CAKeyframeAnimation *oa = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        oa.values = @[@0.6, @1.0, @0.6]; oa.keyTimes = @[@0.0, @0.5, @1.0];
        oa.duration = kGlowDur * 1.5; oa.repeatCount = HUGE_VALF;
        oa.calculationMode = kCAAnimationLinear;
        oa.fillMode = kCAFillModeForwards; oa.removedOnCompletion = NO;

        CAAnimationGroup *g = [CAAnimationGroup animation];
        g.animations = @[ca, oa]; g.duration = kGlowDur * 1.5;
        g.repeatCount = HUGE_VALF; g.fillMode = kCAFillModeForwards;
        g.removedOnCompletion = NO;

        [layer addAnimation:g forKey:@"saoGlow"];
        layer.opacity = 0.8f;
    }
}

- (void)stopGlow {
    if (!_glowing) return;
    _glowing = NO;
    NSArray *layers = @[_top, _bot, _lft, _rgt];
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.4];
    [CATransaction setCompletionBlock:^{
        for (CAShapeLayer *l in layers) {
            [l removeAnimationForKey:@"saoGlow"];
            l.opacity = 0.f;
        }
    }];
    for (CAShapeLayer *l in layers) l.opacity = 0.f;
    [CATransaction commit];
}

@end

// ==============================================================================
#pragma mark - SAOEngine
// ==============================================================================

@interface SAOEngine : NSObject <SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate>
+ (instancetype)shared;
- (void)listenWithDone:(void(^)(void))done;
- (void)cancel;
@end

@implementation SAOEngine {
    SFSpeechRecognizer                    *_rec;
    SFSpeechAudioBufferRecognitionRequest *_req;
    SFSpeechRecognitionTask               *_task;
    AVAudioEngine                         *_audio;
    AVSpeechSynthesizer                   *_tts;
    dispatch_queue_t                       _q;
    NSURLSession                          *_sess;
    void (^_done)(void);
}

+ (instancetype)shared {
    static SAOEngine *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _rec           = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale currentLocale]];
    _rec.delegate  = self;
    _tts           = [[AVSpeechSynthesizer alloc] init];
    _tts.delegate  = self;
    _q = dispatch_queue_create("com.sao.worker",
        dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    NSURLSessionConfiguration *cfg   = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest     = 15;
    cfg.timeoutIntervalForResource    = 30;
    cfg.HTTPMaximumConnectionsPerHost = 1;
    _sess = [NSURLSession sessionWithConfiguration:cfg];
    return self;
}

- (void)listenWithDone:(void(^)(void))done {
    if (!SAOEnabled()) return;
    _done = done;
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus st) {
        if (st != SFSpeechRecognizerAuthorizationStatusAuthorized) {
            if (done) done();
            return;
        }
        dispatch_async(self->_q, ^{ [self _startRec]; });
    }];
}

- (void)_startRec {
    [_task cancel]; _task = nil; _req = nil;
    AVAudioSession *as = [AVAudioSession sharedInstance];
    [as setCategory:AVAudioSessionCategoryPlayAndRecord
        withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker |
                    AVAudioSessionCategoryOptionMixWithOthers error:nil];
    [as setMode:AVAudioSessionModeVoiceChat error:nil];
    [as setActive:YES error:nil];
    _audio = [[AVAudioEngine alloc] init];
    _req   = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if (@available(iOS 13, *)) _req.requiresOnDeviceRecognition = YES;
    _req.shouldReportPartialResults = NO;
    AVAudioInputNode *node = _audio.inputNode;
    [node installTapOnBus:0 bufferSize:4096 format:[node outputFormatForBus:0]
                    block:^(AVAudioPCMBuffer *b, AVAudioTime *t) {
        [self->_req appendAudioPCMBuffer:b];
    }];
    [_audio prepare];
    NSError *err;
    [_audio startAndReturnError:&err];
    if (err) { if (_done) _done(); return; }
    __weak typeof(self) w = self;
    _task = [_rec recognitionTaskWithRequest:_req
        resultHandler:^(SFSpeechRecognitionResult *r, NSError *e) {
            __strong typeof(w) s = w; if (!s) return;
            if (r.isFinal) {
                NSString *txt = r.bestTranscription.formattedString;
                [s _stopAudio];
                if (txt.length) dispatch_async(s->_q, ^{ [s _callAPI:txt]; });
                else if (s->_done) s->_done();
            }
            if (e && e.code != 301) { [s _stopAudio]; if (s->_done) s->_done(); }
        }];
}

- (void)_stopAudio {
    if (_audio.isRunning) { [_audio.inputNode removeTapOnBus:0]; [_audio stop]; }
    [_req endAudio];
}

- (void)_callAPI:(NSString *)prompt {
    NSString *key = SAOKey();
    if (!key.length) { [self _speak:@"Configura la chiave API nelle impostazioni."]; return; }
    NSURLRequest *r = (SAOGetProvider() == SAOProviderGPT)
        ? [self _buildGPTRequest:prompt]
        : [self _buildGeminiRequest:prompt];
    if (!r) return;
    __weak typeof(self) w = self;
    [[_sess dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *_, NSError *e) {
        __strong typeof(w) s = w; if (!s) return;
        if (e) { [s _speak:@"Errore di rete."]; return; }
        NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        NSString *reply = (SAOGetProvider() == SAOProviderGPT)
            ? j[@"choices"][0][@"message"][@"content"]
            : j[@"candidates"][0][@"content"][@"parts"][0][@"text"];
        [s _speak:reply ?: @"Nessuna risposta."];
    }] resume];
}

- (NSURLRequest *)_buildGPTRequest:(NSString *)p {
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:@"https://api.openai.com/v1/chat/completions"]];
    r.HTTPMethod = @"POST";
    [r setValue:[@"Bearer " stringByAppendingString:SAOKey()] forHTTPHeaderField:@"Authorization"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"model": @"gpt-4o-mini", @"max_tokens": @256,
        @"messages": @[
            @{@"role": @"system", @"content": @"Rispondi in massimo 3 frasi."},
            @{@"role": @"user",   @"content": p}
        ]
    } options:0 error:nil];
    return r;
}

- (NSURLRequest *)_buildGeminiRequest:(NSString *)p {
    NSString *url = [NSString stringWithFormat:
        @"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%@",
        SAOKey()];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    r.HTTPMethod = @"POST";
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"contents": @[@{@"parts": @[@{@"text": p}]}],
        @"generationConfig": @{@"maxOutputTokens": @256, @"temperature": @0.7}
    } options:0 error:nil];
    return r;
}

- (void)_speak:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_tts.isSpeaking)
            [self->_tts stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:text];
        u.rate            = AVSpeechUtteranceDefaultSpeechRate;
        u.pitchMultiplier = 1.1f;
        u.volume          = 0.9f;
        u.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"it-IT"]
               ?: [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
        [self->_tts speakUtterance:u];
        if (self->_done) { self->_done(); self->_done = nil; }
    });
}

- (void)cancel {
    [_task cancel]; _task = nil;
    [self _stopAudio];
    if (_tts.isSpeaking) [_tts stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    if (_done) { _done(); _done = nil; }
}

@end

// ==============================================================================
#pragma mark - Darwin C callbacks
// ==============================================================================

static __weak SAOGlowView *s_glow = nil;

static void SAOInstallGlow(void) {
    UIWindow *win = nil;
    if (@available(iOS 15, *)) {
        for (UIWindowScene *sc in [UIApplication sharedApplication].connectedScenes)
            if ([sc isKindOfClass:[UIWindowScene class]]) { win = sc.keyWindow; break; }
    } else {
        win = [UIApplication sharedApplication].keyWindow;
    }
    if (!win || s_glow) return;
    SAOGlowView *g = [[SAOGlowView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [win addSubview:g];
    [win bringSubviewToFront:g];
    s_glow = g;
}

static void SAOOnStart(CFNotificationCenterRef c, void *o,
                       CFStringRef n, const void *obj, CFDictionaryRef i) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [s_glow startGlow];
        [[SAOEngine shared] listenWithDone:^{
            dispatch_async(dispatch_get_main_queue(), ^{ [s_glow stopGlow]; });
        }];
    });
}

static void SAOOnStop(CFNotificationCenterRef c, void *o,
                      CFStringRef n, const void *obj, CFDictionaryRef i) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[SAOEngine shared] cancel];
        [s_glow stopGlow];
    });
}

// ==============================================================================
#pragma mark - SpringBoard group
// ==============================================================================

%group SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)app {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        SAOInstallGlow();
        [SAOEngine shared];
        CFNotificationCenterRef dc = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(dc, NULL, SAOOnStart,
            (__bridge CFStringRef)kHerySiriStart, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(dc, NULL, SAOOnStop,
            (__bridge CFStringRef)kHerySiriStop, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

%end

%hook SiriUIUnderstandingOnDeviceHandler

- (void)handleOnDeviceSpeechRecognitionResult:(id)result {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kHerySiriStart, NULL, NULL, YES);
}

- (void)presentUI {
}

%end

%hook SiriUIAssistantWindowController

- (void)presentWithAnimation:(BOOL)animated {
}

%end

%end

// ==============================================================================
#pragma mark - AssistantD group
// ==============================================================================

%group AssistantD

%hook AFSiriActivationConnection

- (void)connectionDidActivate:(id)activation {
    NSLog(@"[SAO] AFSiriActivationConnection - Hey Siri intercettato");
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kHerySiriStart, NULL, NULL, YES);
}

%end

%end

// ==============================================================================
#pragma mark - ctor
// ==============================================================================

%ctor {
    @autoreleasepool {
        NSString *proc = [NSProcessInfo processInfo].processName;
        if ([proc isEqualToString:@"SpringBoard"]) {
            %init(SpringBoard);
        } else if ([proc isEqualToString:@"assistantd"]) {
            if (NSClassFromString(@"AFSiriActivationConnection")) {
                %init(AssistantD);
            }
        }
    }
}
