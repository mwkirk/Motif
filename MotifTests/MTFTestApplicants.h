//
//  MTFTestApplicants.h
//  Motif
//
//  Created by Eric Horacek on 1/7/16.
//  Copyright © 2016 Eric Horacek. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Motif/Motif.h>

@interface MTFTestCTypePropertiesApplicant : NSObject

@property (nonatomic) char charValue;
@property (nonatomic) int intValue;
@property (nonatomic) short shortValue;
@property (nonatomic) long longValue;
@property (nonatomic) long long longLongValue;
@property (nonatomic) unsigned char unsignedCharValue;
@property (nonatomic) unsigned int unsignedIntValue;
@property (nonatomic) unsigned short unsignedShortValue;
@property (nonatomic) unsigned long unsignedLongValue;
@property (nonatomic) unsigned long long unsignedLongLongValue;
@property (nonatomic) float floatValue;
@property (nonatomic) float doubleValue;
@property (nonatomic) bool boolValue;
@property (nonatomic) CGSize sizeValue;
@property (nonatomic) CGPoint pointValue;

@end

@interface MTFTestObjCClassPropertiesApplicant : NSObject

@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, copy) NSNumber *numberValue;

@end

@interface MTFTestSuperclassPropertyApplicant : NSObject

@property (nonatomic, copy) NSNumber *superclassProperty;

@end

@interface MTFTestSubclassPropertyApplicant : MTFTestSuperclassPropertyApplicant

@end

@interface MTFTestThemeClassPropertyApplicant : NSObject

@property (nonatomic) MTFThemeClass *themeClass;

@end

@interface MTFTestThemeClassNestedPropertyApplicant : NSObject

@property (nonatomic) MTFTestObjCClassPropertiesApplicant *nestedApplicant;

@end

typedef NS_ENUM(NSInteger, MTFTestEnumeration) {
    MTFTestEnumeration1,
    MTFTestEnumeration2,
    MTFTestEnumeration3
};

@interface MTFTestEnumerationPropertiesApplicant : NSObject

@property (nonatomic) MTFTestEnumeration enumeration;

@end

@interface MTFTestSetterCountingApplicant : NSObject

@property (readonly, nonatomic) NSInteger applications;

@property (nonatomic, copy) NSString *stringValue;

@end
