//
//  JNKeychain.h
//
//  Created by Jeremias Nunez on 5/10/13.
//  Copyright (c) 2013 Jeremias Nunez. All rights reserved.
//
//  Based on Anomie's great answer - http://stackoverflow.com/a/5251820
//
//  jeremias.np@gmail.com

#import <Foundation/Foundation.h>

@interface JNKeychain : NSObject

/**
  @abstract Saves a given value to the Keychain for a specific keychain access group
  @param value The value to store.
  @param key The key identifying the value you want to save.
  @param group The keychain access group name, used to share the data across apps.
  @return YES if saved successfully, NO otherwise.
 */
+ (BOOL)saveValue:(id)value forKey:(NSString*)key forAccessGroup:(NSString *)group;

/**
 @abstract Saves a given value to the Keychain
 @param value The value to store.
 @param key The key identifying the value you want to save.
 @return YES if saved successfully, NO otherwise.
 */
+ (BOOL)saveValue:(id)value forKey:(NSString*)key;

/**
  @abstract Deletes a given value from the Keychain for a specific keychain access group
  @param key The key identifying the value you want to delete.
  @param group The keychain access group name, used to share the data across apps.
  @return YES if deletion was successful, NO if the value was not found or some other error ocurred.
 */
+ (BOOL)deleteValueForKey:(NSString *)key forAccessGroup:(NSString *)group;

/**
 @abstract Deletes a given value from the Keychain
 @param key The key identifying the value you want to delete.
 @return YES if deletion was successful, NO if the value was not found or some other error ocurred.
 */
+ (BOOL)deleteValueForKey:(NSString *)key;

/**
  @abstract Loads a given value from the Keychain for a specific keychain access group
  @param key The key identifying the value you want to load.
  @param group The keychain access group name, used to share the data across apps.
  @return The value identified by key or nil if it doesn't exist.
 */
+ (id)loadValueForKey:(NSString*)key forAccessGroup:(NSString *)group;

/**
 @abstract Loads a given value from the Keychain
 @param key The key identifying the value you want to load.
 @return The value identified by key or nil if it doesn't exist.
 */
+ (id)loadValueForKey:(NSString*)key;

/**
 @abstract Returns bundle seed ID for the current application
 @return The value of bundle seed ID wor nil if failed to get the property
 */
+ (NSString *)getBundleSeedIdentifier;

@end
