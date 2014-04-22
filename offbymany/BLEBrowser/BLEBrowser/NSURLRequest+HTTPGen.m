//
//  NSURLRequest+HTTPGen.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import "NSURLRequest+HTTPGen.h"

@implementation NSURLRequest (HTTPGen)

- (NSData *)HTTPRequest {
    CFHTTPMessageRef message = CFHTTPMessageCreateRequest(NULL,
                                                          (__bridge CFStringRef)self.HTTPMethod,
                                                          (__bridge CFURLRef)self.URL,
                                                          kCFHTTPVersion1_1);

    for (NSString *header in self.allHTTPHeaderFields) {
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)header,
                                         (__bridge CFStringRef)self.allHTTPHeaderFields[header]);
    }

    // HTTP/1.1 requires a Host header. Make one up.
    if (![self.allHTTPHeaderFields objectForKey:@"Host"]) {
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)@"Host",
                                         (__bridge CFStringRef)@"GATT");
    }

    if (self.HTTPBody.length > 0) {
        CFHTTPMessageSetHeaderFieldValue(message,
                                         (__bridge CFStringRef)@"Content-Length",
                                         (__bridge CFStringRef)[NSString stringWithFormat:@"%lu", (unsigned long)self.HTTPBody.length]);
    }

    CFHTTPMessageSetBody(message, (__bridge CFDataRef)self.HTTPBody);

    NSData *requestData = CFBridgingRelease(CFHTTPMessageCopySerializedMessage(message));
    CFRelease(message);

    return requestData;
}

@end
