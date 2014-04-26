//
//  BBURLProtocol.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <Foundation/Foundation.h>
#import "BBConnection.h"
#import "BBChunkReader.h"

@interface BBURLProtocol : NSURLProtocol<BBConnectionDelegate, BBChunkReaderDelegate>

@end
