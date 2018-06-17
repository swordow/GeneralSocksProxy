#import <openssl/evp.h>
#import <QuartzCore/QuartzCore.h>
#import "configuration.h"
#import "SWBConfigWindowController.h"
#import "ss_worker.h"
#import "encrypt.h"


@implementation SWBConfigWindowController {
    Config *configuration;
}


- (void)windowWillLoad {
    [super windowWillLoad];
}

- (void)addMethods {
    for (int i = 0; i < kGSPMethods; i++) {
        const char* method_name = GSP_encryption_names[i];
        NSString *methodName = [[NSString alloc] initWithBytes:method_name length:strlen(method_name) encoding:NSUTF8StringEncoding];
        [_methodBox addItemWithObjectValue:methodName];
    }
}

- (void)loadSettings {
    NSString* configPath = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @".GSP"];
    NSString* ssConfig = [NSString stringWithFormat:@"%@/%@", configPath, @"config.txt"];
    configuration = load_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
    if (configuration->size == 0)
    {
        if (worker_is_using_public_server())
        {
            configuration->current = -1;
        }
        else
        {
            configuration->current = 0;
            Profile* profile = create_profile(worker_ip(), worker_port(), worker_password(), worker_method(), "");
            add_profile(configuration, profile);
        }
    }
}

- (void)saveSettings {
    NSString* configPath = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @".GSP"];
    NSString* ssConfig = [NSString stringWithFormat:@"%@/%@", configPath, @"config.txt"];
    save_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if (self.tableView.selectedRow < 0) {
        // always allow no selection to selection
        return YES;
    }
    if (row >= 0 && row < configuration->size) {
        if ([self validateCurrentProfile]) {
            [self saveCurrentProfile];
        } else {
            return NO;
        }
    }
    // always allow selection to no selection
    return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (self.tableView.selectedRow >= 0) {
        [self loadCurrentProfile];
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row >= configuration->size)
    {
        return @"New Server";
    }
    Profile* profile = configuration->profiles[row];
    return [[NSString alloc] initWithCString:(profile->server) encoding:(NSUTF8StringEncoding)];
}

- (IBAction)sectionClick:(id)sender {
    NSInteger index = ((NSSegmentedControl *)sender).selectedSegment;
    if (index == 0) {
        [self add:sender];
    } else if (index == 1) {
        [self remove:sender];
    }
}

- (IBAction)add:(id)sender {
    if (configuration->size != 0 && ![self saveCurrentProfile]) {
        [self shakeWindow];
        return;
    }
    Profile* profile = create_profile("", "8388", "", "aes-256-cfb", "");
    add_profile(configuration, profile);
    
    [self.tableView reloadData];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(configuration->size - 1)] byExtendingSelection:NO];
    [self updateSettingsBoxVisible:self];
    [self loadCurrentProfile];
}

- (IBAction)remove:(id)sender {
    NSInteger selection = self.tableView.selectedRow;
    if (selection >= configuration->size) return;
    
        remove_profile(configuration, (int)selection);
        //[((NSMutableArray *) configuration.profiles) removeObjectAtIndex:selection];
        [self.tableView reloadData];
        [self updateSettingsBoxVisible:self];
        if (configuration->size > 0) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(configuration->size - 1)] byExtendingSelection:NO];
        }
        [self loadCurrentProfile];
        if (configuration->current > selection) {
            // select the original profile
            configuration->current = configuration->current - 1;
        }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return configuration->size;
}

- (void)windowDidLoad {
    [self loadSettings];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [super windowDidLoad];
    [self addMethods];
    [self.tableView reloadData];
    [self loadCurrentProfile];
    [self updateSettingsBoxVisible:self];
}

- (IBAction)updateSettingsBoxVisible:(id)sender {
    if (configuration->size == 0) {
        [_settingsBox setHidden:YES];
        [_placeholderLabel setHidden:NO];
    } else {
        [_settingsBox setHidden:NO];
        [_placeholderLabel setHidden:YES];
    }
}

- (void)loadCurrentProfile {
    if (configuration->size < 1 ) return;
    if (self.tableView.selectedRow >= configuration->size) return;
    
            Profile *profile = configuration->profiles[self.tableView.selectedRow];
            [_serverField setStringValue:
             [[NSString alloc] initWithCString:(profile->server) encoding:(NSUTF8StringEncoding)]];
            [_portField setStringValue:
             [[NSString alloc] initWithCString:(profile->port) encoding:(NSUTF8StringEncoding)]];
            [_methodBox setStringValue:
             [[NSString alloc] initWithCString:(profile->method) encoding:(NSUTF8StringEncoding)]];
            [_passwordField setStringValue:
             [[NSString alloc] initWithCString:(profile->password) encoding:(NSUTF8StringEncoding)]];
            [_remarksField setStringValue:
             [[NSString alloc] initWithCString:(profile->remarks) encoding:(NSUTF8StringEncoding)]];
}

- (BOOL)saveCurrentProfile {
    if (![self validateCurrentProfile]) {
        return NO;
    }
    if (self.tableView.selectedRow >= configuration->size) return NO;

        struct Profile *profile = configuration->profiles[self.tableView.selectedRow];
        
        update_profile(profile,
                       [[_serverField stringValue] cStringUsingEncoding:(NSUTF8StringEncoding)],
                       [[_portField stringValue] cStringUsingEncoding:(NSUTF8StringEncoding)],
                       [[_passwordField stringValue] cStringUsingEncoding:(NSUTF8StringEncoding)],
                       [[_methodBox stringValue] cStringUsingEncoding:(NSUTF8StringEncoding)],
                       [[_remarksField stringValue] cStringUsingEncoding:(NSUTF8StringEncoding)]);
    return YES;
}

- (BOOL)validateCurrentProfile {
    if ([[_serverField stringValue] isEqualToString:@""]) {
        [_serverField becomeFirstResponder];
        return NO;
    }
    if ([_portField integerValue] == 0) {
        [_portField becomeFirstResponder];
        return NO;
    }
    if ([[_methodBox stringValue] isEqualToString:@""]) {
        [_methodBox becomeFirstResponder];
        return NO;
    }
    if ([[_passwordField stringValue] isEqualToString:@""]) {
        [_passwordField becomeFirstResponder];
        return NO;
    }
    return YES;
}

- (IBAction)OK:(id)sender {
    if ([self saveCurrentProfile]) {
        [self saveSettings];
        worker_reload_config();
        [self.delegate configurationDidChange];
        [self.window performClose:self];
    } else {
        [self shakeWindow];
    }
}

- (IBAction)cancel:(id)sender {
    [self.window performClose:self];
}

- (void)shakeWindow {
    static int numberOfShakes = 3;
    static float durationOfShake = 0.7f;
    static float vigourOfShake = 0.03f;

    CGRect frame=[self.window frame];
    CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];

    CGMutablePathRef shakePath = CGPathCreateMutable();
    CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
    int index;
    for (index = 0; index < numberOfShakes; ++index)
    {
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
        CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
    }
    CGPathCloseSubpath(shakePath);
    shakeAnimation.path = shakePath;
    shakeAnimation.duration = durationOfShake;

    [self.window setAnimations:[NSDictionary dictionaryWithObject: shakeAnimation forKey:@"frameOrigin"]];
    [[self.window animator] setFrameOrigin:[self.window frame].origin];
}

@end
