//
//  NSURLRequest+BBConnection.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <Foundation/Foundation.h>
#import "BBConnection.h"

@interface NSURLRequest (BBConnection)

@property(nonatomic, strong, readonly) BBConnection *conn;

@end


@interface NSMutableURLRequest (BBConnection)

@property(nonatomic, strong, readwrite) BBConnection *conn;

@end

