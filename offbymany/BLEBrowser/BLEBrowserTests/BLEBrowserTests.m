//
//  BLEBrowserTests.m
//  BLEBrowserTests
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <XCTest/XCTest.h>
#import "BBChunkReader.h"

@interface BLEBrowserTests : XCTestCase<BBChunkReaderDelegate>

@property(strong) NSMutableData *received;
@property(assign) BOOL done;
@property(strong) NSString *name;

@end


@implementation BLEBrowserTests

- (void)testChunkExhaustive {
    NSString *chunked = @"24\r\nNow is the winter of our discontent\n\r\n2a\r\nMade glorious summer by this sun of York;\n\r\n2e\r\nAnd all the clouds that lour'd upon our house\n\r\n26\r\nIn the deep bosom of the ocean buried.\r\n0\r\n";

    for (NSUInteger i = 1; i < chunked.length; i++) {
        for (NSUInteger j = i; j < chunked.length; j++) {
            for (NSUInteger k = j; k < chunked.length; k++) {
                @autoreleasepool {
                    self.name = [NSString stringWithFormat:@"Test: %lu %lu %lu", i, j, k];
                    self.received = [NSMutableData data];
                    self.done = NO;
                    BBChunkReader *r = [[BBChunkReader alloc] init];
                    r.delegate = self;
                    [r writeData:[[chunked substringWithRange:NSMakeRange(0, i-0)] dataUsingEncoding:NSASCIIStringEncoding]];
                    [r writeData:[[chunked substringWithRange:NSMakeRange(i, j-i)] dataUsingEncoding:NSASCIIStringEncoding]];
                    [r writeData:[[chunked substringWithRange:NSMakeRange(j, k-j)] dataUsingEncoding:NSASCIIStringEncoding]];
                    [r writeData:[[chunked substringWithRange:NSMakeRange(k, chunked.length-k)] dataUsingEncoding:NSASCIIStringEncoding]];
                    XCTAssertTrue(self.done, @"Chunk reader should have completed: %@", self.name);
                }
            }
        }
    }
}

- (void)chunkReader:(BBChunkReader *)reader didReceiveData:(NSData *)data {
    [self.received appendData:data];
}

- (void)chunkReaderDidFinishReceivingData:(BBChunkReader *)reader {
    NSData *want = [@"Now is the winter of our discontent\nMade glorious summer by this sun of York;\nAnd all the clouds that lour'd upon our house\nIn the deep bosom of the ocean buried." dataUsingEncoding:NSASCIIStringEncoding];
    XCTAssertTrue([want isEqualToData:self.received], @"Wrong chunk decoding for %@: got\n---\n%@\n---\n---\nwant\n%@",
                  self.name,
                  [[NSString alloc] initWithData:self.received encoding:NSASCIIStringEncoding],
                  [[NSString alloc] initWithData:want encoding:NSASCIIStringEncoding]
                  );
    self.done = YES;
}

@end
