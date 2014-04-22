//
//  BBChunkReader.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

// Modified from TouchCode (https://github.com/TouchCode/TouchHTTPD). Original license header:

//
//  CChunkWriter.m
//  TouchCode
//
//  Created by Jonathan Wight on 12/30/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "BBChunkReader.h"


@interface BBChunkReader ()

@property (readwrite, assign) NSInteger remainingChunkLength;
@property (readwrite, strong) NSData *unparsedData;

@end


@implementation BBChunkReader

- (id)init
{
    if ((self = [super init]) != NULL)
	{
        self.remainingChunkLength = 0;
	}
    return(self);
}


- (void)writeData:(NSData *)inData {
    NSData *parseData = nil;
    if (self.unparsedData.length > 0) {
        NSMutableData *mParseData = [self.unparsedData mutableCopy];
        [mParseData appendData:inData];
        parseData = mParseData;
    } else {
        parseData = inData;
    }

    NSInteger theChunkLength = self.remainingChunkLength;
    if (theChunkLength == -1)
	{
        // JIWTODO error!
        NSLog(@"CHUNKING ERROR #0");
	}

    const char *START = parseData.bytes, *END = START + parseData.length, *P = START;

    while (START < END)
	{
        if (self.remainingChunkLength == 0)
		{
            for (; P != END && *P != '\r'; ++P)
			{
                if (ishexnumber(*P) == NO)
				{
                    // JIWTODO error!
                    NSLog(@"CHUNKING ERROR #1");
				}
			}
            theChunkLength = strtol(START, NULL, 16);

            if (P == END) {
                self.unparsedData = [NSData dataWithBytes:START length:END-START];
                return;
            }

            if (*P++ != '\r')
			{
                // JIWTODO error!
                NSLog(@"CHUNKING ERROR #2");
			}
            if (P == END) {
                self.unparsedData = [NSData dataWithBytes:START length:END-START];
                return;
            }

            if (*P++ != '\n')
			{
                // JIWTODO error!
                NSLog(@"CHUNKING ERROR #2.5");
			}
            if (P == END && theChunkLength != 0) {
                self.unparsedData = [NSData dataWithBytes:START length:END-START];
                return;
            }

            if (theChunkLength == 0)
			{
                // We are done!
                self.remainingChunkLength = -1;
                [self.delegate chunkReaderDidFinishReceivingData:self];
                return;
			}

			theChunkLength += 2;		// calculate \n\r suffix too
		}

        NSInteger theAvailableLength = MIN(END - P, theChunkLength);
        self.remainingChunkLength = theChunkLength - theAvailableLength;

        // do not write terminating \n\r if this is a tail of current chunk
        NSInteger writeLength = (self.remainingChunkLength < 2) ? theAvailableLength - (2 - self.remainingChunkLength) : theAvailableLength;
        if (writeLength > 0)
		{
            NSData *theChunk = [[NSData alloc] initWithBytes:(void *)P length:writeLength];
            [self.delegate chunkReader:self didReceiveData:theChunk];
            self.unparsedData = nil;
		}

        P += theAvailableLength;
        START = P;
	}
}



@end
