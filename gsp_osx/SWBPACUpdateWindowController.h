#import <Cocoa/Cocoa.h>

@protocol SWBPACUpdateWindowControllerDelegate <NSObject>

@optional
- (void)pacURLDidChange;

@end

@interface SWBPACUpdateWindowController : NSWindowController
@property (weak) IBOutlet NSTextField *url;
- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

@property (nonatomic, weak) id<SWBPACUpdateWindowControllerDelegate> delegate;

@end
