# JNKeychain

[![CI Status](http://img.shields.io/travis/jeremangnr/JNKeychain.svg?style=flat)](https://travis-ci.org/jeremangnr/JNKeychain)
[![Version](https://img.shields.io/cocoapods/v/JNKeychain.svg?style=flat)](http://cocoadocs.org/docsets/JNKeychain)
[![License](https://img.shields.io/cocoapods/l/JNKeychain.svg?style=flat)](http://cocoadocs.org/docsets/JNKeychain)
[![Platform](https://img.shields.io/cocoapods/p/JNKeychain.svg?style=flat)](http://cocoadocs.org/docsets/JNKeychain)

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first. The example project only contains a few sample calls to save, load and delete values in the viewDidLoad method of jnViewController:

    NSString *testKey = @"myTestKey";
    NSString *testValue = @"myTestValue";

    if ([JNKeychain saveValue:testValue forKey:testKey]) {
        NSLog(@"Correctly saved value '%@' for key '%@'", testValue, testKey);
    } else {
        NSLog(@"Failed to save!");
    }

    NSLog(@"Value for key '%@' is: '%@'", testKey, [JNKeychain loadValueForKey:testKey]);

    if ([JNKeychain deleteValueForKey:testKey]) {
        NSLog(@"Deleted value for key '%@'. Value is: %@", testKey, [JNKeychain loadValueForKey:testKey]);
    } else {
        NSLog(@"Failed to delete!");
    }

In order to share the keychain data across different applications enable Keychain Sharing access group under project capabilities, add Security.framework to the Linked Frameworks and Libraries and use the methods which expect access group:

    NSString *accessGroup = @"demo.JNKeychain.shared";

    if ([JNKeychain saveValue:testValue forKey:testKey forAccessGroup:accessGroup]) {
        NSLog(@"Correctly saved value '%@' for key '%@'", testValue, testKey);
    } else {
        NSLog(@"Failed to save!");
    }

    NSLog(@"Value for key '%@' is: '%@'", testKey, [JNKeychain loadValueForKey:testKey forAccessGroup:accessGroup]);

    if ([JNKeychain deleteValueForKey:testKey forAccessGroup:accessGroup]) {
        NSLog(@"Deleted value for key '%@'. Value is: %@", testKey, [JNKeychain loadValueForKey:testKey forAccessGroup:accessGroup]);
    } else {
        NSLog(@"Failed to delete!");
    }

If you don't want to use Cocoapods you can just grab the JNKeychain.h and JNKeychain.m files and put them somewhere in your project.

## Requirements

JNKeychain uses ARC.

## Installation

JNKeychain is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

    pod "JNKeychain"

## Author

Jeremias Nunez, jeremias.np@gmail.com - [@jereahrequesi](https://twitter.com/jereahrequesi)

## License

JNKeychain is available under the MIT license. See the LICENSE file for more info.

