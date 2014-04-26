//
//  BBConnection.m
//  BLEBrowser
//
//  See https://github.com/gophercon/2014-talks/offbymany for license.
//

#import "BBConnection.h"

#define dispatch_seconds 1000000000 // nanoseconds in a second

@interface BBConnection ()

@property(strong, readwrite) CBUUID *serviceUUID;
@property(strong, readwrite) CBUUID *readUUID;
@property(strong, readwrite) CBUUID *writeUUID;

@property(strong, readwrite) NSMutableData *pendingWrites;
@property(assign, readwrite) BOOL connected; // Are we ready for reading + writing?
@property(assign, readwrite) BOOL writing; // Are we in the middle of a write?

@property(strong, readwrite) CBCentralManager *central;
@property(strong, readwrite) CBPeripheral *per;
@property(strong, readwrite) CBService *stream;
@property(strong, readwrite) CBCharacteristic *reader;
@property(strong, readwrite) CBCharacteristic *writer;
@property(strong) dispatch_queue_t queue;

@end

@implementation BBConnection

- (id)initWithServiceUUID:(CBUUID *)s readUUID:(CBUUID *)r writeUUID:(CBUUID *)w {
    self = [super init];
    if (self) {
        self.queue = dispatch_queue_create("com.offbymany.blecentral", DISPATCH_QUEUE_SERIAL);
        self.central = [[CBCentralManager alloc] initWithDelegate:self queue:self.queue options:@{CBCentralManagerOptionShowPowerAlertKey: @(YES)}];
        self.serviceUUID = s;
        self.readUUID = r;
        self.writeUUID = w;
        NSLog(@"BBConnection: %@ / %@ / %@", self.serviceUUID, self.readUUID, self.writeUUID);
        self.pendingWrites = [NSMutableData data];
    }
    return self;
}

- (void)connect {
    if (!self.per) {
        [self scan];
    }
}

- (void)disconnect {
    NSLog(@"Triggering disconnect");

    NSArray *peripherals = [self.central retrieveConnectedPeripheralsWithServices:@[self.serviceUUID]];
    for (CBPeripheral *per in peripherals) {
        [self.central cancelPeripheralConnection:per];
    }
    self.per = nil;
    self.stream = nil;
    self.reader = nil;
    self.writer = nil;
    self.connected = NO;
    [self.pendingWrites setLength:0];
}

- (void)reconnectLater {
    NSLog(@"Reconnecting later...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * dispatch_seconds), dispatch_get_main_queue(), ^{
        NSLog(@"Reconnecting now");
        [self scan];
    });
}

- (void)write:(NSData *)data {
    NSLog(@"Write: `%@`", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    [self.pendingWrites appendData:data];
    if (!self.connected) {
        return;
    }

    [self writeNextPacket];
    // the callback will trigger subseqeuent writes, as needed
}

// writeNextPacket sends the next packet's worth of data to write from self.pendingWrites.
- (void)writeNextPacket {
    if (self.pendingWrites.length == 0 || self.writing) {
        return;
    }

    NSUInteger len = self.pendingWrites.length < 20 ? self.pendingWrites.length : 20;
    NSData *packet = [self.pendingWrites subdataWithRange:NSMakeRange(0, len)];
    [self.pendingWrites setData:[self.pendingWrites subdataWithRange:NSMakeRange(len, self.pendingWrites.length-len)]];

//    NSLog(@"Send packet: `%@`", [[NSString alloc] initWithData:packet encoding:NSUTF8StringEncoding]);
    [self.per writeValue:packet
       forCharacteristic:self.writer
                    type:CBCharacteristicWriteWithResponse];
    self.writing = YES;
}

- (void)scan {
    NSLog(@"Scanning");
    NSArray *peripherals = [self.central retrieveConnectedPeripheralsWithServices:@[self.serviceUUID]];
    if (peripherals.count > 0) {
        NSLog(@"Using connected peripheral: %@", peripherals[0]);
        [self centralManager:self.central didDiscoverPeripheral:peripherals[0] advertisementData:nil RSSI:@(0)];
        return;
    }
    NSLog(@"Scanning for peripherals");
    [self.central scanForPeripheralsWithServices:@[self.serviceUUID] options:nil];
}

- (void)didConnect {
    NSLog(@"Did connect");
    self.connected = YES;
    [self write:nil]; // trigger any pending writes
}

#pragma mark - CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"centralManagerDidUpdateState: %ld", central.state);
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self scan];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered peripheral: %@", peripheral);
    if (!self.per) {
        self.per = peripheral;
        self.per.delegate = self;
        NSLog(@"Connecting to peripheral: %@", peripheral);
        [self.central stopScan];
        [self.central connectPeripheral:peripheral options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected to peripheral: %@", peripheral);
    self.stream = nil;
    if (!peripheral.services) {
        NSLog(@"Discovering services %@", self.serviceUUID);
        [peripheral discoverServices:@[self.serviceUUID]];
    } else {
        NSLog(@"Using cached discovered services");
        [self peripheral:peripheral didDiscoverServices:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to peripheral: %@", peripheral);
    self.per = nil;
    [self reconnectLater];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected from peripheral %@, error %@", peripheral, error);
    if (error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate BBConnection:self didEncounterError:error];
        });
    }
    self.per = nil;
    [self reconnectLater];
}

#pragma mark - CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering services: %@", error);
        [self disconnect];
        [self reconnectLater];
        return;
    }

    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service.UUID);
        if ([service.UUID isEqual:self.serviceUUID]) {
            self.stream = service;
            break;
        }
    }

    if (self.stream == nil) {
        NSLog(@"Failed to discover service %@", self.serviceUUID);
        [self disconnect];
        return;
    }

    if (!self.stream.characteristics) {
        NSArray *chars = @[self.readUUID, self.writeUUID];
        NSLog(@"Discovering characteristics %@", chars);
        [peripheral discoverCharacteristics:chars forService:self.stream];
    } else {
        NSLog(@"Using cached characteristics %@", self.stream.characteristics);
        [self peripheral:peripheral didDiscoverCharacteristicsForService:self.stream error:nil];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error discovering characteristics: %@", error);
        [self disconnect];
        return;
    }

    BOOL foundRead = NO;
    BOOL foundWrite = NO;

    NSLog(@"Discovered characteristics: %@", service.characteristics);
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:self.writeUUID]) {
            self.writer = characteristic;
            if (self.reader && self.reader.isNotifying) {
                [self didConnect];
            }
            foundWrite = YES;
        } else if ([characteristic.UUID isEqual:self.readUUID]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            foundRead = YES;
        }
    }

    if (!foundRead || !foundWrite) {
        NSLog(@"Did not find both read and write characteristics (%d %d)", foundRead, foundWrite);
        [self disconnect];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error requesting characteristic notification: %@", error);
        [self disconnect];
        return;
    }

    if ([characteristic.UUID isEqual:self.readUUID] && characteristic.isNotifying) {
        NSLog(@"Characteristic is notifying: %@", characteristic);
        self.reader = characteristic;
        if (self.writer) {
            [self didConnect];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
//    NSLog(@"Updated value: %@", characteristic.value);
    if (error || ![characteristic.UUID isEqual:self.reader.UUID] || !characteristic.value) {
        NSLog(@"Ignoring value: %@ %@", error, characteristic.UUID);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate BBConnection:self didRead:characteristic.value];
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    self.writing = NO;
    if (error) {
        NSLog(@"Error writing to characteristic: %@", error);
        [self.delegate BBConnection:self didEncounterError:error];
        [self disconnect];
        return;
    }

    [self writeNextPacket];
}

@end
