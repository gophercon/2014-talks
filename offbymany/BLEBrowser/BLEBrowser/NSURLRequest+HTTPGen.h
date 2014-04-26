//
//  NSURLRequest+HTTPGen.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (HTTPGen)

// Generates a bytes-on-the-wire HTTP request
- (NSData *)HTTPRequest;

@end
