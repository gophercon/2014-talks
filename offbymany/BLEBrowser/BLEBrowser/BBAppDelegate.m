//
//  BBAppDelegate.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import "BBAppDelegate.h"
#import "BBURLProtocol.h"
#import "NSURLRequest+BBConnection.h"
#import "BBConnection.h"

#define RequestTimeout 24 * 60 * 60 // Give each request a whole day. They can be *very* slow to complete.

#define ServiceUUID [CBUUID UUIDWithString:@"39170DC9-E537-43B0-AE6E-F7D2DE3031E0"]
#define ReadUUID    [CBUUID UUIDWithString:@"77500CA7-CD0D-4FFE-88CD-07A3E8F509A5"]
#define WriteUUID   [CBUUID UUIDWithString:@"275E9963-D7E4-47A5-B43A-8BFC360F5032"]

@interface BBAppDelegate ()

@property(strong, readwrite) BBConnection *conn;

@end

@implementation BBAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Register our custom BBURLProtocol
    [NSURLProtocol registerClass:[BBURLProtocol class]];

    // Set up our shared BLE conn, used for all requests
    self.conn = [[BBConnection alloc] initWithServiceUUID:ServiceUUID readUUID:ReadUUID writeUUID:WriteUUID];

    // Kick off the first request
    NSURL *url = [NSURL URLWithString:@"bbconn:/"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:RequestTimeout];
    [self.web.mainFrame loadRequest:request];

    // Make webview scale with window
    [self.window setContentView:self.web];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

// Close all Bluetooth connections on our way out
- (void)applicationWillTerminate:(NSNotification *)aNotification {
    NSArray *peripherals = [self.conn.central retrieveConnectedPeripheralsWithServices:@[ServiceUUID]];
    for (CBPeripheral *peripheral in peripherals) {
        [self.conn.central cancelPeripheralConnection:peripheral];
    }
}

- (id)webView:(WebView *)sender identifierForInitialRequest:(NSURLRequest *)request fromDataSource:(WebDataSource *)dataSource {
    return [request URL];
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    NSLog(@"WebView will request %@", identifier);
    NSMutableURLRequest *mut = [request mutableCopy];
    mut.conn = self.conn;
    mut.timeoutInterval = RequestTimeout;
    return mut;
}

- (void)webView:(WebView *)sender resource:(id)identifier didFailLoadingWithError:(NSError *)error fromDataSource:(WebDataSource *)dataSource {
    NSLog(@"WebView failed to load resource %@, error %@", identifier, error);
}

- (void)webView:(WebView *)sender resource:(id)identifier didFinishLoadingFromDataSource:(WebDataSource *)dataSource {
    NSLog(@"WebView finished loading %@", identifier);
}


@end
