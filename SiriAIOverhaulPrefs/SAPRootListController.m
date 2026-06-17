#import <Preferences/PSListController.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

static NSString *const kPrefsDomain = @"com.tuonome.siriaioverhaul";
static NSString *const kPrefsPath   = @"/var/jb/var/mobile/Library/Preferences/com.tuonome.siriaioverhaul.plist";
static NSString *const kPrefsNotify = @"com.tuonome.siriaioverhaul.prefsChanged";

@interface SAPRootListController : PSListController
@end

@implementation SAPRootListController {
    NSMutableDictionary *_prefs;
}

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}

- (NSString *)title {
    return @"SiriAI Overhaul";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    _prefs = [NSMutableDictionary dictionaryWithDictionary:d ?: @{}];

    UILabel *lbl      = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 60)];
    lbl.text          = @"SiriAI Overhaul";
    lbl.font          = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    lbl.textColor     = [UIColor systemBlueColor];
    lbl.textAlignment = NSTextAlignmentCenter;
    UIView *hdr       = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 80)];
    lbl.center        = hdr.center;
    [hdr addSubview:lbl];
    self.table.tableHeaderView = hdr;
}

- (id)readPreferenceValue:(PSSpecifier *)spec {
    NSString *key = spec.properties[@"key"];
    if (!key) return nil;
    return _prefs[key] ?: spec.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)spec {
    NSString *key = spec.properties[@"key"];
    if (!key) return;
    if (value) _prefs[key] = value;
    else [_prefs removeObjectForKey:key];

    BOOL ok = [_prefs writeToFile:kPrefsPath atomically:YES];
    if (!ok) {
        NSString *dir = [kPrefsPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:nil];
        [_prefs writeToFile:kPrefsPath atomically:YES];
    }

    CFPreferencesSetMultiple((__bridge CFDictionaryRef)_prefs, NULL,
        (__bridge CFStringRef)kPrefsDomain,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize((__bridge CFStringRef)kPrefsDomain,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kPrefsNotify, NULL, NULL, YES);
}

@end
