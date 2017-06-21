//
//  ViewController.m
//  LostAndFound
//
//  Created by SAI KATTERISHETTY on 6/18/17.
//  Copyright © 2017 SAI KATTERISHETTY. All rights reserved.
//

#import "ViewController.h"
@import CoreBluetooth;
@import QuartzCore;
@import AVFoundation;

@interface ViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate>
@property (weak, nonatomic) IBOutlet UILabel *lblConnectionStatus;
@property (assign, nonatomic) BOOL deviceStatus;
@property (strong, nonatomic) CBCentralManager *cbCentralManager;
@property (strong, nonatomic) CBPeripheral *cbPeripheral;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (strong, nonatomic) CBCharacteristic *cbCharacterstic;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.cbCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    [self setDeviceConnectionStatus];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reconnectToBluetoothPeripheral) name:UIApplicationWillEnterForegroundNotification object:nil];
}


- (IBAction)ringButton:(id)sender {
    NSString *message = @"You are not connected to Bluetooth Device Yet";
    
    if(! self.deviceStatus) {
        return [self showAlert:message];
    }
    
    [self writeImmediateAlertLevelToTag:self.cbCharacterstic AndImmediateAlertLevel:2];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.stopButton.alpha = 1;
    }];
}

- (IBAction)stopRinging:(id)sender {
    NSString *message = @"You are not connected to Bluetooth Device Yet";
    
    if(! self.deviceStatus) {
        return [self showAlert:message];
    }
    
    [self writeImmediateAlertLevelToTag:self.cbCharacterstic AndImmediateAlertLevel:0];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.stopButton.alpha = 0;
    }];
}

-(BOOL) isPeripheralConnected {
    return  (self.cbPeripheral && self.cbPeripheral.state == CBPeripheralStateConnected);
}


- (void) reconnectToBluetoothPeripheral {
    NSLog(@"Application Did Enter Forground Device");
    self.deviceStatus =  [self isPeripheralConnected];
    NSLog(@"Peripheral Status: %@",  self.deviceStatus ? @"Online" : @"Offline");
    [self setDeviceConnectionStatus];
    if(! [self isPeripheralConnected]){
        [self.activityIndicator startAnimating];
        [self.cbCentralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:ITAG_ADVERTISEMENT]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    }
}

-(void) showAlert:(NSString *) message {
    UIAlertController *uiaAlertController = [UIAlertController alertControllerWithTitle:@"Lost & Found" message:message preferredStyle: UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [uiaAlertController dismissViewControllerAnimated:YES completion:nil];
    }];
    
    [uiaAlertController addAction:cancelAction];
    
    [self presentViewController:uiaAlertController animated:YES completion:nil];

}

-(void) setDeviceConnectionStatus {
    self.lblConnectionStatus.text = self.deviceStatus ? @"Connected": @"Disconnected";
}


#pragma mark - CBCentralManagerDelegate

// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"Connected to new device -> %@", peripheral.name);
    self.deviceStatus = [self isPeripheralConnected];
    [peripheral discoverServices:@[[CBUUID UUIDWithString:ITAG_ALERT_SERVICE], [CBUUID UUIDWithString:ITAG_ADVERTISEMENT]]];
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Found new Advertisement");
    
    NSString *localName = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    
    if( [localName length] > 0 ){
        [self.cbCentralManager stopScan];
        self.cbPeripheral = peripheral;
        self.cbPeripheral.delegate = self;
        [self.cbCentralManager connectPeripheral:self.cbPeripheral options:nil];
    }
    
}

// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSLog(@"Device State Updated");
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"State Powered On");
        [self.cbCentralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:ITAG_ADVERTISEMENT]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
        NSLog(@"Scanning started");
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Device Disconnected");
    self.deviceStatus = NO;
    self.cbPeripheral = nil;
    self.cbCharacterstic = nil;
    [self setDeviceConnectionStatus];
    [self.activityIndicator startAnimating];
    [self.cbCentralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:ITAG_ADVERTISEMENT]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}

#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    for (CBService *service in peripheral.services) {
        NSLog(@"Service -> %@", service.UUID);
        [peripheral discoverCharacteristics:@[] forService:service];
    }
    
}

// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    for (CBCharacteristic *characteristic in service.characteristics) {
         NSLog(@"Characterstic %@" , characteristic.UUID);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:ITAG_ALERT_SERVICE_CHARACTERSTIC ]]){
            self.cbCharacterstic = characteristic;
            [self setDeviceConnectionStatus];
            
            [self.activityIndicator stopAnimating];
            
        }else if([characteristic.UUID isEqual:[CBUUID UUIDWithString: ITAG_ADVERTISEMENT_CHARACTERSTIC]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"Device Characteristics Updated");
    
    if (error) {
        NSLog(@"Error");
        return;
    }
    [self readButtonValue:characteristic];
}

- (void) writeImmediateAlertLevelToTag:(CBCharacteristic *) immediateAlertAlertLevelCharacteristic AndImmediateAlertLevel:(UInt8) immediateAlertLevel
{
    NSData* data = [NSData dataWithBytes:&immediateAlertLevel length:1];
    [self.cbPeripheral writeValue:data forCharacteristic:immediateAlertAlertLevelCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

- (void) readButtonValue:(CBCharacteristic *)characteristic
{
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString: ITAG_ADVERTISEMENT_CHARACTERSTIC]]){
        [self showAlert:@" You have An Alert from the button"];
        AudioServicesPlaySystemSound (systemSoundID);
    }
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
