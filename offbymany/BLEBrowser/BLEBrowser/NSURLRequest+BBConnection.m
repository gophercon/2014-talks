//
//  NSURLRequest+BBConnection.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import "NSURLRequest+BBConnection.h"

#define BBConnKey @"BBConnection"

@implementation NSURLRequest (BBConnection)

@dynamic conn;

- (BBConnection *)conn {
    return [NSURLProtocol propertyForKey:BBConnKey inRequest:self];
}

@end

@implementation NSMutableURLRequest (BBConnection)

@dynamic conn;

- (void)setConn:(BBConnection *)conn {
    if (!conn) {
        [NSURLProtocol removePropertyForKey:BBConnKey inRequest:self];
    } else {
        [NSURLProtocol setProperty:conn forKey:BBConnKey inRequest:self];
    }
}

@end

