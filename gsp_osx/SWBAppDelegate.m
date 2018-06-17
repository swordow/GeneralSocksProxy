#import "pac.h"
#import "ss_worker.h"
#import "configuration.h"
#import "proxy_conf.h"
#import "SWBConfigWindowController.h"
#import "SWBQRCodeWindowController.h"
#import "SWBPACUpdateWindowController.h"
#import "SWBAppDelegate.h"

#define _L(s) NSLocalizedString(@#s, nil)

#define kGSPIsRunningKey @"GSPIsRunning"
#define kGSPRunningModeKey @"GSPMode"

@implementation SWBAppDelegate {
    SWBPACUpdateWindowController *pacUpdateWindowController;
    SWBConfigWindowController *configWindowController;
    SWBQRCodeWindowController *qrCodeWindowController;
    NSMenuItem *statusMenuItem;
    NSMenuItem *enableMenuItem;
    NSMenuItem *autoMenuItem;
    NSMenuItem *globalMenuItem;
    NSMenuItem *qrCodeMenuItem;
    NSMenu *serversMenu;
    BOOL isRunning;
    NSString *runningMode;
    NSData *originalPACData;
    FSEventStreamRef fsEventStream;
    NSString *configPath;
    NSString *PACPath;
    NSString *userRulePath;
    NSString *ssConfig;
    Config* configuration;
}

static SWBAppDelegate *appDelegate;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
    // init all paths
    configPath = [NSString stringWithFormat:@"%@/%@", NSHomeDirectory(), @".gsp"];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:configPath])
    {
        [fileManager createDirectoryAtPath:configPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    PACPath = [NSString stringWithFormat:@"%@/%@", configPath, @"pac_working.js"];
    userRulePath = [NSString stringWithFormat:@"%@/%@", configPath, @"user-rule.txt"];
    ssConfig = [NSString stringWithFormat:@"%@/%@", configPath, @"config.txt"];
    NSString* pacTemplatePath = [NSString stringWithFormat:@"%@/%@", configPath, @"pac_template.js"];
    NSString* pacDefaultPath = [NSString stringWithFormat:@"%@/%@", configPath, @"pac_default.js"];
    
    // copy bundle abp.js to .gsp
    NSData *nsdata = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"abp" withExtension:@"js"]];
    NSString *data = [[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding];
    [[data dataUsingEncoding:NSUTF8StringEncoding] writeToFile:pacTemplatePath atomically:YES];
    
    // copy bundle proxy.pac to .gsp
    nsdata = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"proxy" withExtension:@"pac"]];
    data = [[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding];
    [[data dataUsingEncoding:NSUTF8StringEncoding] writeToFile:pacDefaultPath atomically:YES];
    
    // init pac
    pac_init([pacTemplatePath cStringUsingEncoding:NSUTF8StringEncoding],
             [pacDefaultPath cStringUsingEncoding:NSUTF8StringEncoding],
             [PACPath cStringUsingEncoding:NSUTF8StringEncoding]);
    

    // init worker
    worker_init();
    pac_server_start();
    
    // run proxy
    dispatch_queue_t proxy = dispatch_queue_create("proxy", NULL);
    dispatch_async(proxy, ^{
        [self runProxy];
    });
   
    self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:20];
    NSImage *image = [NSImage imageNamed:@"menu_icon"];
    [image setTemplate:YES];
    self.item.image = image;
    self.item.highlightMode = YES;
    
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"GSP"];
    [menu setMinimumWidth:200];
    
    statusMenuItem = [[NSMenuItem alloc] initWithTitle:_L(GSP Off) action:nil keyEquivalent:@""];
    
    enableMenuItem = [[NSMenuItem alloc] initWithTitle:_L(Turn GSP Off) action:@selector(toggleRunning) keyEquivalent:@""];
//    [statusMenuItem setEnabled:NO];
    autoMenuItem = [[NSMenuItem alloc] initWithTitle:_L(Auto Proxy Mode) action:@selector(enableAutoProxy) keyEquivalent:@""];
//    [enableMenuItem setState:1];
    globalMenuItem = [[NSMenuItem alloc] initWithTitle:_L(Global Mode) action:@selector(enableGlobal)
        keyEquivalent:@""];
    
    [menu addItem:statusMenuItem];
    [menu addItem:enableMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:autoMenuItem];
    [menu addItem:globalMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];

    serversMenu = [[NSMenu alloc] init];
    NSMenuItem *serversItem = [[NSMenuItem alloc] init];
    [serversItem setTitle:_L(Servers)];
    [serversItem setSubmenu:serversMenu];
    [menu addItem:serversItem];

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:_L(Edit PAC for Auto Proxy Mode...) action:@selector(editPAC) keyEquivalent:@""];
    [menu addItemWithTitle:_L(Edit PAC Update URL...) action:@selector(editPACUpdateURL) keyEquivalent:@""];
    [menu addItemWithTitle:_L(Update PAC...) action:@selector(updatePAC) keyEquivalent:@""];
    [menu addItemWithTitle:_L(Edit User Rule for PAC List...) action:@selector(editUserRule) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    qrCodeMenuItem = [[NSMenuItem alloc] initWithTitle:_L(Generate QR Code...) action:@selector(showQRCode) keyEquivalent:@""];
    [menu addItem:qrCodeMenuItem];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:_L(Scan QR Code from Screen...) action:@selector(scanQRCode) keyEquivalent:@""]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:_L(Show Logs...) action:@selector(showLogs) keyEquivalent:@""];
    [menu addItemWithTitle:_L(Help) action:@selector(showHelp) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:_L(Quit) action:@selector(exit) keyEquivalent:@""];
    self.item.menu = menu;
    
    configuration = load_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
    config_reload_worker();
    //[self installHelper];
    [self initializeProxy];
    [self monitorPAC:configPath];
    [self updateMenu];
    appDelegate = self;
}



- (void)enableAutoProxy {
    runningMode = @"auto";
    [[NSUserDefaults standardUserDefaults] setValue:runningMode forKey:kGSPRunningModeKey];
    [self updateMenu];
    [self reloadSystemProxy];
}

- (void)enableGlobal {
    runningMode = @"global";
    [[NSUserDefaults standardUserDefaults] setValue:runningMode forKey:kGSPRunningModeKey];
    [self updateMenu];
    [self reloadSystemProxy];
}

- (void)chooseServer:(id)sender {
    NSInteger tag = [sender tag];
    if (tag == -1 || tag < configuration->size) {
        configuration->current = (int)tag;
    }
    save_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
    [self updateServersMenu];
}

- (void)updateServersMenu {
    //Config * configuration = load_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
    [serversMenu removeAllItems];
    int i = 0;
    NSMenuItem *publicItem = [[NSMenuItem alloc] initWithTitle:_L(Public Server) action:@selector(chooseServer:) keyEquivalent:@""];
    publicItem.tag = -1;
    if (-1 == configuration->current) {
        [publicItem setState:1];
    }
    [serversMenu addItem:publicItem];
    for (int j=0; i<configuration->size;++j) {
        struct Profile *profile = configuration->profiles[j];
        NSString *title;
        title = [NSString stringWithFormat:@"%s (%s:%s)",
                 profile->remarks, profile->server, profile->port];
      
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(chooseServer:) keyEquivalent:@""];
        item.tag = i;
        if (i == configuration->current) {
            [item setState:1];
        }
        [serversMenu addItem:item];
        i++;
    }
    [serversMenu addItem:[NSMenuItem separatorItem]];
    [serversMenu addItemWithTitle:_L(Open Server Preferences...) action:@selector(showConfigWindow) keyEquivalent:@""];
    
}

- (void)updateMenu {
    if (isRunning) {
        statusMenuItem.title = _L(GSP: On);
        enableMenuItem.title = _L(Turn GSP Off);
        NSImage *image = [NSImage imageNamed:@"menu_icon"];
        [image setTemplate:YES];
        self.item.image = image;
    } else {
        statusMenuItem.title = _L(GSP: Off);
        enableMenuItem.title = _L(Turn GSP On);
        NSImage *image = [NSImage imageNamed:@"menu_icon_disabled"];
        [image setTemplate:YES];
        self.item.image = image;
    }
    
    if ([runningMode isEqualToString:@"auto"]) {
        [autoMenuItem setState:1];
        [globalMenuItem setState:0];
    } else if([runningMode isEqualToString:@"global"]) {
        [autoMenuItem setState:0];
        [globalMenuItem setState:1];
    }
    if (worker_is_using_public_server()/*[GSPRunner isUsingPublicServer]*/) {
        [qrCodeMenuItem setTarget:nil];
        [qrCodeMenuItem setAction:NULL];
    } else {
        [qrCodeMenuItem setTarget:self];
        [qrCodeMenuItem setAction:@selector(showQRCode)];
    }
    [self updateServersMenu];
}



- (void)reloadSystemProxy {
    if (isRunning) {
        [self toggleSystemProxy:NO];
        [self toggleSystemProxy:YES];
    }
}

- (void)monitorPAC:(NSString *)pacPath {
    if (fsEventStream) {
        return;
    }
    CFStringRef mypath = (__bridge CFStringRef)(pacPath);
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&mypath, 1, NULL);
    void *callbackInfo = NULL; // could put stream-specific data here.
    CFAbsoluteTime latency = 3.0; /* Latency in seconds */

    /* Create the stream, passing in a callback */
    fsEventStream = FSEventStreamCreate(NULL,
            &onPACChange,
            callbackInfo,
            pathsToWatch,
            kFSEventStreamEventIdSinceNow, /* Or a previous event ID */
            latency,
            kFSEventStreamCreateFlagNone /* Flags explained in reference */
    );
    FSEventStreamScheduleWithRunLoop(fsEventStream, [[NSRunLoop mainRunLoop] getCFRunLoop], (__bridge CFStringRef)NSDefaultRunLoopMode);
    FSEventStreamStart(fsEventStream);
}

- (void)editPAC {

    if (![[NSFileManager defaultManager] fileExistsAtPath:PACPath]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:NO attributes:nil error:&error];
        // TODO check error
        [originalPACData writeToFile:PACPath atomically:YES];
    }
    [self monitorPAC:configPath];
    
    NSArray *fileURLs = @[[NSURL fileURLWithPath:PACPath]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}


- (void)editUserRule {
  
  if (![[NSFileManager defaultManager] fileExistsAtPath:userRulePath]) {
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:configPath withIntermediateDirectories:NO attributes:nil error:&error];
    // TODO check error
    [@"! Put user rules line by line in this file.\n! See https://adblockplus.org/en/filter-cheatsheet\n" writeToFile:userRulePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
  }
  
  NSArray *fileURLs = @[[NSURL fileURLWithPath:userRulePath]];
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}



- (void)showLogs {
    [[NSWorkspace sharedWorkspace] launchApplication:@"/Applications/Utilities/Console.app"];
}

- (void)showHelp {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"https://github.com/gsp/gsp-iOS/wiki/GSP-for-OSX-Help", nil)]];
}

- (void)showConfigWindow {
    if (configWindowController) {
        [configWindowController close];
    }
    configWindowController = [[SWBConfigWindowController alloc] initWithWindowNibName:@"ConfigWindow"];
    configWindowController.delegate = self;
    [configWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [configWindowController.window makeKeyAndOrderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    NSLog(@"terminating");
    if (isRunning) {
        [self toggleSystemProxy:NO];
    }
}

- (void)configurationDidChange {
    [self updateMenu];
}



- (void)runProxy {
    worker_reload_config();//[GSPRunner reloadConfig];
    for (; ;) {
        if (worker_run_proxy()/*[GSPRunner runProxy]*/) {
            sleep(1);
        } else {
            sleep(2);
        }
    }
}

- (void)exit {
    [[NSApplication sharedApplication] terminate:nil];
}

- (void)initializeProxy {
    runningMode = [self runningMode];
    id isRunningObject = [[NSUserDefaults standardUserDefaults] objectForKey:kGSPIsRunningKey];
    if ((isRunningObject == nil) || [isRunningObject boolValue]) {
        [self toggleSystemProxy:YES];
    }
    [self updateMenu];
}

- (void)toggleRunning {
    [self toggleSystemProxy:!isRunning];
    [[NSUserDefaults standardUserDefaults] setBool:isRunning forKey:kGSPIsRunningKey];
    [self updateMenu];
}

- (NSString *)runningMode {
    NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:kGSPRunningModeKey];
    if (mode) {
        return mode;
    }
    return @"auto";
}

- (void)toggleSystemProxy:(BOOL)useProxy {
    isRunning = useProxy;
    NSString *param;
    if (useProxy) {
        param = [self runningMode];
    } else {
        param = @"off";
    }
    proxy_set_mode([param cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:_L(OK)];
    [alert addButtonWithTitle:_L(Cancel)];
    [alert setMessageText:_L(Use this server?)];
    [alert setInformativeText:url];
    [alert setAlertStyle:NSInformationalAlertStyle];
    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        NSURL* ssurl = [NSURL URLWithString:url];
        if (!ssurl.host)
        {
            alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:_L(OK)];
            [alert setMessageText:@"Invalid GSP URL"];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert runModal];
        }
        
        NSString* urlString1 = [ssurl absoluteString];
        NSData* data = [[NSData alloc] initWithBase64Encoding:ssurl.host];
        NSString* decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString* urlString2 = decodedString;
        
        if (worker_update_from_url([[[NSString alloc] initWithString:urlString1] cStringUsingEncoding:NSUTF8StringEncoding])==0)
        {
            return;
        }
        if (worker_update_from_url([[[NSString alloc] initWithString:urlString2] cStringUsingEncoding:NSUTF8StringEncoding])==0)
        {
            return;
        }
        alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:_L(OK)];
        [alert setMessageText:@"Invalid GSP URL"];
        [alert setAlertStyle:NSCriticalAlertStyle];
        [alert runModal];
    }
}
// ==================================== PAC ====================================
- (void)updatePAC
{
    int error = pac_update_from_url();
    if (error == -1)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Updated Failed";
        [alert runModal];
    }
    else
    {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Updated";
        [alert runModal];
    }
}

- (void)editPACUpdateURL
{
    if (pacUpdateWindowController) {
        [pacUpdateWindowController close];
    }
    pacUpdateWindowController = [[SWBPACUpdateWindowController alloc] initWithWindowNibName:@"PACUpdateWindow"];
    pacUpdateWindowController.delegate = self;
    [pacUpdateWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [pacUpdateWindowController.window makeKeyAndOrderFront:nil];
}

- (NSData *)PACData {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PACPath]) {
        return [NSData dataWithContentsOfFile:PACPath];
    } else {
        return originalPACData;
    }
}

- (void)pacURLDidChange
{
    save_config([ssConfig cStringUsingEncoding:NSUTF8StringEncoding]);
}

void onPACChange(
                 ConstFSEventStreamRef streamRef,
                 void *clientCallBackInfo,
                 size_t numEvents,
                 void *eventPaths,
                 const FSEventStreamEventFlags eventFlags[],
                 const FSEventStreamEventId eventIds[])
{
    [appDelegate reloadSystemProxy];
}

// ================================== QR ========================================
- (void)showQRCode {
    const char* curl = worker_generate_ssurl();
    if (curl == 0)
    {
        return;
    }
    NSString* urlString = [[NSString alloc] initWithCString: curl encoding:NSUTF8StringEncoding];
    
    NSURL *qrCodeURL = [NSURL URLWithString:urlString]; //[GSPRunner generateSSURL];
    qrCodeWindowController = [[SWBQRCodeWindowController alloc] initWithWindowNibName:@"QRCodeWindow"];
    qrCodeWindowController.qrCode = [qrCodeURL absoluteString];
    [qrCodeWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
    [qrCodeWindowController.window makeKeyAndOrderFront:nil];
}


@end
