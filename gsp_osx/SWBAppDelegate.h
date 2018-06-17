#import <Cocoa/Cocoa.h>

@interface SWBAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem* item;

@end
