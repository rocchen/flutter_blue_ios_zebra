#import "FlutterBlueIosZebraPlugin.h"
#import <ExternalAccessory/ExternalAccessory.h>
#import "ZebraPrinterConnection.h"
#import "MfiBtPrinterConnection.h"
#import "ZebraPrinter.h"
#import "ZebraPrinterFactory.h"


#define CASE(str) if ([__s__ isEqualToString:(str)])
#define SWITCH(s) for (NSString *__s__ = (s); ; )
#define DEFAULT



@interface FlutterBlueIosZebraPlugin()
@property (nonatomic, strong) NSMutableArray *accessoryList;
@property (nonatomic, strong) EAAccessory *selectedAccessory;
@end


@implementation FlutterBlueIosZebraPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"com.jax.flutter_blue_ios_zebra"
            binaryMessenger:[registrar messenger]];
  FlutterBlueIosZebraPlugin* instance = [[FlutterBlueIosZebraPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    SWITCH([call method]){
        CASE(@ "getPlatformVersion") {
            result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
            break;
        }
        CASE(@"regis") {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
            [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];

            _accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];

            result(@(YES));
            break;
        }
        CASE(@"unregis") {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidDisconnectNotification object:nil];

            _accessoryList = nil;
            result(@(YES));
            break;
        }
        CASE(@"list"){
            NSLog(@"=================== IOS ===================");
            for (EAAccessory *accessory in _accessoryList) {
                NSLog(@"Accessory name: %@", [accessory name]);
                NSLog(@"Manufacturer: %@", [accessory manufacturer]);
                NSLog(@"Model number: %@", [accessory modelNumber]);
                NSLog(@"Serial number: %@", [accessory serialNumber]);
                NSLog(@"HW Revision: %@", [accessory hardwareRevision]);
                NSLog(@"FW Revision: %@", [accessory firmwareRevision]);
                NSLog([accessory isConnected] ? @"YES": @"NO");
                NSLog(@"Connection ID: %lu", (unsigned long)[accessory connectionID]);
                NSLog(@"Protocol strings: %@", [accessory protocolStrings]);
                NSLog(@"==========================================");
            }
            break;
        }
        CASE(@"getDriverList"){
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

            for (EAAccessory *accessory in _accessoryList) {
                [dictionary setObject:[NSString stringWithFormat:@"%lu", (unsigned long)accessory.connectionID] forKey:[NSString stringWithString:accessory.name]];
            }

            result(dictionary);
            break;
        }
        CASE(@"writeText"){

            NSDictionary *arguments = [call arguments];
            NSString *printer = [arguments objectForKey:@"printer"];
            NSString *strLength = [arguments objectForKey:@"length"];
            int length = [strLength intValue];

            if (length > 0) {
                // search printer
                bool isFound = NO;

                for (EAAccessory *accessory in _accessoryList) {
                    if ([accessory.name.lowercaseString compare:printer.lowercaseString] == NSOrderedSame) {
                        _selectedAccessory = accessory;
                        isFound = YES;
                        break;
                    }
                }

                if (!isFound) {
                    result(@(NO));
                    break;
                }

                MfiBtPrinterConnection *connection = [[MfiBtPrinterConnection alloc] initWithSerialNumber:_selectedAccessory.serialNumber] ;
                BOOL didOpen = [connection open];

                if(!didOpen) {
                    result(@(NO));
                    break;
                }
                dispatch_queue_t queue = dispatch_queue_create("com.jax.flutter_blue_ios_zebra", DISPATCH_QUEUE_SERIAL);
                // 获取主队列
                dispatch_queue_t mainQueue = dispatch_get_main_queue();

                dispatch_async(queue, ^{
                    NSError *error = nil;
                    id<ZebraPrinter,NSObject> printer = [ZebraPrinterFactory getInstance:connection error:&error];
                    if(printer != nil) {
                        for (int index = 0; index < length; index++) {
                            NSString *dataPrinter = [arguments objectForKey:[NSString stringWithFormat:@"data%d", index]];
                            [[printer getToolsUtil] sendCommand:dataPrinter error:&error];
                        }
                        result(@(YES));
                    }else{
                        result(@(NO));
                    }

                });

            }

            break;
        }
        DEFAULT {
            result(FlutterMethodNotImplemented);
            break;
        }
    }
}

#pragma mark Internal
- (void)_accessoryDidConnect:(NSNotification *)notification {
    EAAccessory *connectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];

    [_accessoryList addObject:connectedAccessory];
}

- (void)_accessoryDidDisconnect:(NSNotification *)notification {
    EAAccessory *disconnectedAccessory = [[notification userInfo] objectForKey:EAAccessoryKey];

    int disconnectedAccessoryIndex = 0;
    for (EAAccessory *accessory in _accessoryList) {
        if([disconnectedAccessory connectionID] == [accessory connectionID]) {
            break;
        }
        disconnectedAccessoryIndex++;
    }

    if (disconnectedAccessoryIndex < [_accessoryList count]) {
        [_accessoryList removeObjectAtIndex:disconnectedAccessoryIndex];
    } else {
        NSLog(@"could not find disconnected accessory in accessory list");
    }
}
@end

