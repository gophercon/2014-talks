//
//  BBChunkReader.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

// Modified from TouchCode (https://github.com/TouchCode/TouchHTTPD). Original license header:

//
//  CChunkWriter.h
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

#import <Foundation/Foundation.h>

@class BBChunkReader;

@protocol BBChunkReaderDelegate <NSObject>

- (void)chunkReader:(BBChunkReader *)reader didReceiveData:(NSData *)data;
- (void)chunkReaderDidFinishReceivingData:(BBChunkReader *)reader;

@end


@interface BBChunkReader : NSObject

@property(weak, readwrite) id<BBChunkReaderDelegate> delegate;

- (void)writeData:(NSData *)inData;

@end
