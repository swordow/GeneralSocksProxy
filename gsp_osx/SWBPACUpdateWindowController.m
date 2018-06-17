#import <openssl/evp.h>
#import <QuartzCore/QuartzCore.h>
#import "configuration.h"
#import "SWBPACUpdateWindowController.h"
#import "ss_worker.h"
#import "encrypt.h"


@implementation SWBPACUpdateWindowController

- (void)windowWillLoad
{
    [super windowWillLoad];
}
- (IBAction)ok:(id)sender
{
    config_set_pac_update_url([[_url stringValue] cStringUsingEncoding:NSUTF8StringEncoding]);
    [self.delegate pacURLDidChange];
    [self.window performClose:self];
}

- (IBAction)cancel:(id)sender
{
    [self.window performClose:self];
}

- (void)windowDidLoad
{
    [_url setStringValue:
     [[NSString alloc] initWithCString:config_get_pac_update_url() encoding:(NSUTF8StringEncoding)]];
    [super windowDidLoad];
}
@end
    
