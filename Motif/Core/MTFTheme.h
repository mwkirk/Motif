//
//  MTFTheme.h
//  Motif
//
//  Created by Eric Horacek on 12/22/14.
//  Copyright (c) 2014 Eric Horacek. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Motif/MTFThemeApplier.h>

@class MTFThemeClass;

NS_ASSUME_NONNULL_BEGIN

/**
 A collection of classes and constants used to style interface objects.
 
 Themes are immutable. If you want to change the theme that is applied to an
 object at runtime, use an MTFDynamicThemeApplier or any of its subclasses.
 
 Themes can be created from JSON or YAML theme files, which have the following
 syntax to denote classes and constants:
 
 Classes: Denoted by a leading period (e.g. .Button) and encoded as a nested 
 dictionary/map, a class is a collection of named properties corresponding to
 values that together define the style of an element in your interface. Class
 property values can be any Foundation type, or alternatively references to
 other classes or constants.
 
 Constants: Denoted by a leading dollar sign (e.g. $RedColor) and encoded as 
 a key-value pair, a constant is a named reference to a value. Constant values 
 can be any Foundation types, or alternatively a reference to a class or
 constant.
 */
@interface MTFTheme : NSObject <MTFThemeApplier>

- (instancetype)init NS_UNAVAILABLE;

/**
 Creates a theme object from a theme file with the specified name.
 
 @param themeName The name of the theme file. If the theme file ends with
                  "Theme", then you may alternatively specify only the prefix
                  before "Theme" as the theme name. Required.
 @param error     If an error occurs, upon return contains an NSError object
                  that describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
+ (nullable instancetype)themeFromFileNamed:(NSString *)themeName error:(NSError **)error;

/**
 Creates a theme object from a set of one or mores theme files with the
 specified names.
 
 @param themeNames Names of the theme files as NSStrings. If the theme file ends
                   with "Theme", then you may alternatively specify only the
                   prefix before "Theme" as the theme name. Required.
 @param error      If an error occurs, upon return contains an NSError object
                   that describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
+ (nullable instancetype)themeFromFilesNamed:(NSArray<NSString *> *)themeNames error:(NSError **)error;

/**
 Creates a theme object from a set of one or mores theme files with the
 specified names.
 
 @param themeNames The names of the theme file. If the theme file ends with
                   "Theme", then you may alternatively specify only the prefix
                   before "Theme" as the theme name. Required.
 @param bundle     The bundle that the themes should be loaded from. Optional.
 @param error      If an error occurs, upon return contains an NSError object
                   that describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
+ (nullable instancetype)themeFromFilesNamed:(NSArray<NSString *> *)themeNames bundle:(nullable NSBundle *)bundle error:(NSError **)error;

/**
 Initializes a theme from a theme file.
 
 @param fileURL The NSURL reference to the theme file that the theme object
                should be created from. Required.
 @param error   If an error occurs, upon return contains an NSError object that
                describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
- (nullable instancetype)initWithFile:(NSURL *)fileURL error:(NSError **)error;

/**
 Initializes a theme from a theme file.
 
 @param files An array of NSURL reference to the theme file that the theme
              object should be created from. Required.
 @param error If an error occurs, upon return contains an NSError object that
              describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
- (nullable instancetype)initWithFiles:(NSArray<NSURL *> *)fileURLs error:(NSError **)error;

/**
 Initializes a theme from a theme dictionary.
 
 @param dictionary The dictionary to initialize the theme from. Should follow 
        the syntax of the theme files. Required.

 @param error If an error occurs, upon return contains an NSError object that
        describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
- (nullable instancetype)initWithThemeDictionary:(NSDictionary<NSString *, id> *)dictionary error:(NSError **)error;

/**
 Initializes a theme from an array of theme dictionaries.
 
 @param dictionaries The dictionaries to initialize the theme from. Should 
        mirror the syntax of the theme files. Required.

 @param error If an error occurs, upon return contains an NSError object that
        describes the problem.
 
 @return A theme object, or nil if an error occurred while initializing the
         theme.
 */
- (nullable instancetype)initWithThemeDictionaries:(NSArray<NSDictionary<NSString *, id> *> *)dictionaries error:(NSError **)error;

/**
 The constant value from the theme collection for the specified key.
 
 @param name The name of the desired constant.
 
 @return The constant value for the specified name, or if there is none, `nil`.
 */
- (nullable id)constantValueForName:(NSString *)name;

/**
 The class object for the specified class name.
 
 @param name The name of the desired class.
 
 @return The class for the specified name, or if there is none, `nil`.
 */
- (nullable MTFThemeClass *)classForName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
