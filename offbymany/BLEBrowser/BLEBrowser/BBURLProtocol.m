//
//  BBURLProtocol.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import "BBURLProtocol.h"
#import "NSURLRequest+BBConnection.h"
#import "NSURLRequest+HTTPGen.h"

static dispatch_queue_t sendq; // queue of requests waiting to send
static dispatch_semaphore_t sendsem; // enforce that only one request is in flight at a time

@interface BBURLProtocol ()

@property(assign, readwrite) CFHTTPMessageRef msg;
@property(assign, readwrite) BOOL receivingBody;
@property(assign, readwrite) BOOL semSignalled;
@property(assign, readwrite) NSInteger remainingContentLength; // for responses with Content-Length
@property(strong, readwrite) BBChunkReader *chunkReader; // for chunked responses
@property(assign, readwrite) BOOL stopped;

@end

@implementation BBURLProtocol

#pragma mark - NSURLProtocol overrides

+ (void)initialize {
    sendq = dispatch_queue_create("com.offbymany.bburlprotocol", NULL);
    sendsem = dispatch_semaphore_create(1);
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request.URL.scheme isEqualToString:@"bbconn"]) {
        return NO;
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

-(void)dealloc {
    [self stopLoading];
}

- (void)startLoading {
    NSLog(@"BBURLProtocol: Start loading %@", self.request.URL);
    dispatch_async(sendq, ^{
        NSLog(@"BBURLProtocol: Enqueued %@", self.request.URL);
        dispatch_semaphore_wait(sendsem, DISPATCH_TIME_FOREVER);
        NSLog(@"BBURLProtocol: Sending %@", self.request.URL);
        self.request.conn.delegate = self;
        self.msg = CFHTTPMessageCreateEmpty(NULL, FALSE);
        NSData *req = [self.request HTTPRequest];
        [self.request.conn write:req];
    });
}

- (void)stopLoading {
//    NSLog(@"BBURLProtocol: Stop loading");
    // Don't actually stop loading; that would break our
    // hopeless simplistic connection model. Instead, just
    // stop sending notifications to the delegate.
    self.stopped = YES;
}

- (void)cleanUp {
    if (self.msg) {
        CFRelease(self.msg);
        self.msg = nil;
    }
    self.chunkReader.delegate = nil;
    self.chunkReader = nil;
}

- (void)done {
    [self signal];
    if (!self.stopped) {
        [self.client URLProtocolDidFinishLoading:self];
    }
    [self cleanUp];
}

- (void)failWithError:(NSError *)error {
    [self signal];
    if (!self.stopped) {
        [self.client URLProtocol:self didFailWithError:error];
    }
    [self cleanUp];
}

- (void)signal {
    if (!self.semSignalled) {
        NSLog(@"BBURLProtocol: %@ is done, allowing next request through", self.request);
        dispatch_semaphore_signal(sendsem); // allow the next request through
        self.semSignalled = YES;
    }
}

#pragma mark - BBConnectionDelegate methods

- (void)BBConnection:(BBConnection *)conn didRead:(NSData *)data {
//    NSLog(@"BBURLProtocol: BBConn received response data %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    if (self.receivingBody) {
        [self didReceiveData:data];
        return;
    }

    // Still receiving the header
    Boolean ok = CFHTTPMessageAppendBytes(self.msg, data.bytes, data.length);

    if (!ok) {
        if (self.msg) {
            CFRelease(self.msg);
        }
        self.msg = nil;
        [self failWithError:[NSError errorWithDomain:@"BBURLProtocol" code:0 userInfo:nil]];
        return;
    }

    if (!CFHTTPMessageIsHeaderComplete(self.msg)) {
        return; // wait for more data
    }

    NSDictionary *headerFields = CFBridgingRelease(CFHTTPMessageCopyAllHeaderFields(self.msg));
    NSInteger statusCode = CFHTTPMessageGetResponseStatusCode(self.msg);

    NSString *version = CFBridgingRelease(CFHTTPMessageCopyVersion(self.msg));

    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:statusCode
                                                             HTTPVersion:version
                                                            headerFields:headerFields];

    if (!self.stopped) {
        NSLog(@"BBURLProtocol: %@ finished reading header", self.request.URL);
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    }

    self.receivingBody = YES;
    if ([[headerFields objectForKey:@"Transfer-Encoding"] isEqualToString:@"chunked"]) {
        self.chunkReader = [[BBChunkReader alloc] init];
        self.chunkReader.delegate = self;
        NSLog(@"%@: chunked", self.request.URL);
    } else {
        self.remainingContentLength = response.expectedContentLength;
        NSLog(@"%@: expected content length: %lu", self.request.URL, self.remainingContentLength);
    }

    // Send any bytes that spilled over into the body
    NSData *body = CFBridgingRelease(CFHTTPMessageCopyBody(self.msg));
    [self didReceiveData:body];

    if (self.msg) {
        CFRelease(self.msg);
    }
    self.msg = nil;
}

- (void)didReceiveData:(NSData *)data {
    if (self.chunkReader) {
        [self.chunkReader writeData:data];
    } else {
        if (!self.stopped) {
            [self.client URLProtocol:self didLoadData:data];
        }
        self.remainingContentLength -= data.length;
        if (self.remainingContentLength <= 0) {
            [self done];
        }
    }
}

- (void)chunkReader:(BBChunkReader *)reader didReceiveData:(NSData *)data {
    NSLog(@"BBURLProtocol: %@ received chunk of size %lu", self.request.URL, data.length);
    if (!self.stopped) {
        [self.client URLProtocol:self didLoadData:data];
    }
}

- (void)chunkReaderDidFinishReceivingData:(BBChunkReader *)reader {
    [self done];
}


- (void)BBConnection:(BBConnection *)conn didEncounterError:(NSError *)error {
    NSLog(@"BBURLProtocol: BBConn didEncounterError %@", error);
    [self failWithError:error];
}

@end
