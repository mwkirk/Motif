//
//  NSObject+ThemeClass.h
//  Motif
//
//  Created by Eric Horacek on 3/25/15.
//  Copyright (c) 2015 Eric Horacek. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Motif/MTFThemeClass.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (ThemeClass)

/// The last theme class that was applied to this object.
@property (nonatomic, weak, nullable, setter=mtf_setThemeClass:) MTFThemeClass *mtf_themeClass;

/// The name of the theme class that was most recently applied to this object.
///
/// Remains populated even if the weak mtf_themeClass property is nilled out
/// due its value being deallocated.
@property (nonatomic, readonly, copy, nullable) NSString *mtf_themeClassName;

@end

NS_ASSUME_NONNULL_END
