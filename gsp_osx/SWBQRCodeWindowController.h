#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface SWBQRCodeWindowController : NSWindowController

@property (nonatomic, strong) IBOutlet WebView *webView;
@property (nonatomic, copy) NSString *qrCode;

@end
