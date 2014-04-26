//
//  BBAppDelegate.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface BBAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet WebView *web;

@end
