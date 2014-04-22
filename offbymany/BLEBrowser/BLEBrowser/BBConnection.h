//
//  BBConnection.h
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>

@class BBConnection;

@protocol BBConnectionDelegate <NSObject>

- (void)BBConnection:(BBConnection *)conn didRead:(NSData *)data;
- (void)BBConnection:(BBConnection *)conn didEncounterError:(NSError *)error;

@end

@interface BBConnection : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>

- (id)initWithServiceUUID:(CBUUID *)s readUUID:(CBUUID *)r writeUUID:(CBUUID *)w;
- (void)write:(NSData *)data;
- (void)disconnect;

@property(strong, readonly) CBCentralManager *central;
@property(weak, readwrite) id<BBConnectionDelegate> delegate;

@end
