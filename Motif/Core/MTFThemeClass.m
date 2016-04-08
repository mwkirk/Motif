//
//  MTFThemeClass.m
//  Motif
//
//  Created by Eric Horacek on 12/22/14.
//  Copyright (c) 2014 Eric Horacek. All rights reserved.
//

#import "NSValueTransformer+TypeFiltering.h"
#import "NSObject+ThemeClassAppliersPrivate.h"
#import "NSObject+ThemeClass.h"
#import "NSString+ThemeSymbols.h"

#import "MTFRuntimeExtensions.h"
#import "MTFThemeClass.h"
#import "MTFThemeClass_Private.h"
#import "MTFTheme.h"
#import "MTFTheme_Private.h"
#import "MTFThemeConstant.h"
#import "MTFThemeClassApplicable.h"
#import "MTFErrors.h"
#import "MTFValueTransformerErrorHandling.h"

NS_ASSUME_NONNULL_BEGIN

@implementation MTFThemeClass

#pragma mark - Lifecycle

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Use the designated initializer instead" userInfo:nil];
}

- (instancetype)initWithName:(NSString *)name propertiesConstants:(NSDictionary<NSString *, MTFThemeConstant *> *)propertiesConstants {
    NSParameterAssert(name != nil);
    NSParameterAssert(propertiesConstants != nil);

    self = [super init];

    _name = [name copy];
    _propertiesConstants = [propertiesConstants copy];
    _resolvedPropertiesConstants = [self createResolvedPropertiesConstantsFromPropertiesConstants:_propertiesConstants];
    _properties = [self createPropertiesFromResolvedPropertiesConstants:_resolvedPropertiesConstants];

    return self;
}

#pragma mark - MTFThemeClass

#pragma mark Public

- (BOOL)applyTo:(id)applicant error:(NSError **)error {
    NSParameterAssert(applicant != nil);

    // If the theme class has already been applied to the applicant, do no
    // reapply.
    if ([applicant mtf_themeClass] == self) return YES;

    // Contains the names of properties that were not able to be applied to the
    // object.
    NSMutableSet<NSString *> *unappliedProperties = [NSMutableSet setWithArray:self.properties.allKeys];

    // Contains the errors that occurred while applying properties to the
    // object.
    NSMutableArray<NSError *> *errors = [NSMutableArray array];

    // Contains the names of properties that were not able to be applied to the
    // object.
    NSMutableSet<NSString *> *propertiesWithErrors = [NSMutableSet set];

    // Determine whether we're dealing with an object instance or an ObjC Class.
    // If it's a Class, we'll use its UIAppearance proxy as the instance.
    BOOL isClass = class_isMetaClass(object_getClass(applicant));
    Class applicantClass;
    id applicantInstance;
    
    if (isClass) {
        // @TODO: Does passing in an id<UIAppearanceContainer> (e.g. UIViewController) that doesn't
        //        conform to UIAppearance break things?
        applicantClass = applicant;
        applicantInstance = [applicant appearance];
        BOOL hasProtocol = [applicantClass conformsToProtocol:@protocol(UIAppearance)] || [applicantClass conformsToProtocol:@protocol(UIAppearanceContainer)];
        NSAssert(hasProtocol == YES, @"Class %@ does not conform to the UIAppearance or UIAppearanceContainer protocol", applicantClass);
    }
    else {
        applicantClass = [applicant class];
        applicantInstance = applicant;
    }
    
    // First, attempt to apply each of the class appliers registered on the
    // applicant's class.
    for (id<MTFThemeClassApplicable> classApplier in [applicantClass mtf_themeClassAppliers]) {
        NSError *applierError;
        NSSet<NSString *> *appliedProperties = [classApplier applyClass:self to:applicantInstance error:&applierError];
        
        if (appliedProperties != nil) {
            [unappliedProperties minusSet:appliedProperties];
        } else {
            [unappliedProperties minusSet:classApplier.properties];
            [propertiesWithErrors unionSet:classApplier.properties];

            if (applierError != nil) {
                [errors addObject:applierError];
            }
        }
    }

    NSDictionary<NSString *, MTFThemeConstant *> *resolvedPropertiesConstants = self.resolvedPropertiesConstants;
    
    // Second, for each of the properties that had no appliers, attempt to
    // locate a property on the applicant's class with the same name as the
    // theme class property. If one is found, use KVC to set its value.
    for (NSString *property in [unappliedProperties copy]) {
        // Traverse the class hierarchy from the applicant's class up by
        // superclasses.
        Class traversedApplicantClass = [applicant class];
        do {
            // Locate the first property of the same name as the theme class
            // property in the applicant's class hierarchy.
            objc_property_t objc_property = class_getProperty(
                traversedApplicantClass,
                property.UTF8String);
            
            if (objc_property == NULL) continue;
            
            // Build a property attributes struct to figure out the type of the
            // property.
            mtf_propertyAttributes *propertyAttributes = NULL;
            propertyAttributes = mtf_copyPropertyAttributes(objc_property);
            if (propertyAttributes == NULL) continue;

            Class propertyClass = propertyAttributes->objectClass;
            const char *propertyObjCType = propertyAttributes->type;
            MTFThemeConstant *constant = resolvedPropertiesConstants[property];

            // If it's an Obj-C class object property:
            if (propertyClass != Nil) {
                // If the constant value can be set directly as the value of the
                // property without transformation, do so immediately and break
                // out of the loop.
                if ([constant.value isKindOfClass:propertyClass]) {
                    [unappliedProperties removeObject:property];
                    [self setValue:constant.value forPropertyName:property applicantClass:traversedApplicantClass applicantInstance:applicantInstance applicantIsClass:isClass];
                    break;
                }
            }
            // If it's an Obj-C NSValue type:
            else if (propertyObjCType != NULL) {
                // Whether the property is an C numeric type.
                BOOL isPropertyNumericCType = (
                    strlen(propertyObjCType) == 1
                    && strchr("cislqCISLQfdB", propertyObjCType[0])
                );

                // If it's a numeric C type with an NSNumber equivalent,
                // set it with KVC as no transformation is needed.
                if (isPropertyNumericCType && [constant.value isKindOfClass:NSNumber.class]) {
                    [unappliedProperties removeObject:property];
                    [self setValue:constant.value forPropertyName:property applicantClass:traversedApplicantClass applicantInstance:applicantInstance applicantIsClass:isClass];
                    break;
                }
            }

            // Attempt to locate a value transformer that can be used to
            // transform from the theme class property value to to the type of
            // the property.
            NSValueTransformer *valueTransformer;

            // If it's an Obj-C class object property:
            if (propertyClass != Nil) {
                valueTransformer = [NSValueTransformer
                    mtf_valueTransformerForTransformingObject:constant.value
                    toClass:propertyClass];
            }
            // If it's an Obj-C NSValue type:
            else if (propertyObjCType != NULL) {
                valueTransformer = [NSValueTransformer
                    mtf_valueTransformerForTransformingObject:constant.value
                    toObjCType:propertyObjCType];
            }
            
            free(propertyAttributes);
            
            // If a value transformer is found for the property, use KVC to set
            // the transformed theme class property value on the applicant
            // object, and break out of this loop.
            if (valueTransformer != nil) {
                [unappliedProperties removeObject:property];

                NSError *valueTransformationError;
                id transformedValue = [constant transformedValueFromTransformer:valueTransformer error:&valueTransformationError];

                if (transformedValue != nil) {
                    [self setValue:transformedValue forPropertyName:property applicantClass:traversedApplicantClass applicantInstance:applicantInstance applicantIsClass:isClass];
                    break;
                }

                [propertiesWithErrors addObject:property];

                if (valueTransformationError != nil) {
                    [errors addObject:valueTransformationError];
                }

                break;
            }
            
            BOOL isPropertyTypeThemeClass = (propertyClass == MTFThemeClass.class);
            BOOL isValueThemeClass = [constant.value isKindOfClass:MTFThemeClass.class];
            // If the applicantInstance is a UIAppearance proxy, we can't use valueForKey
            id propertyValue = (isValueThemeClass) ? [applicantInstance valueForKey:property] : nil;
            
            // If the property currently set to a value and the property being
            // applied is a theme class reference, apply the theme class
            // directly to the property value, unless the property type is a
            // theme class itself.
            if (propertyValue && isValueThemeClass && !isPropertyTypeThemeClass) {
                MTFThemeClass *themeClass = (MTFThemeClass *)constant.value;

                [unappliedProperties removeObject:property];

                NSError *applyPropertyError;
                if (![themeClass applyTo:propertyValue error:&applyPropertyError]) {
                    [propertiesWithErrors addObject:property];

                    if (applyPropertyError != nil) {
                        [errors addObject:applyPropertyError];
                    }
                }

                break;
            }
            
        } while ((traversedApplicantClass = [traversedApplicantClass superclass]));
    }

    BOOL logFailures = getenv("MTF_LOG_THEME_APPLICATION_ERRORS") != NULL;

    // If no appliers nor Obj-C properties were found for any of the properties
    // specified in the theme class, application was unsuccessful.
    if (unappliedProperties.count > 0) {
        if (error == NULL && !logFailures) return NO;

        NSMutableDictionary *unappliedValuesByProperties = [NSMutableDictionary dictionary];
        for (NSString *property in unappliedProperties.allObjects) {
            unappliedValuesByProperties[property] = self.properties[property];
        }

        NSString *description = [NSString stringWithFormat:
            @"Failed to apply the properties %@ from the theme class "\
                "named '%@' to an instance of %@. %@ or any of its "\
                "ancestors must either: (1) Have a readwrite property "\
                "with the same name as the unapplied properties. (2) Have "\
                "an applier block registered for the unapplied properties.",
            [unappliedProperties.allObjects componentsJoinedByString:@", "],
            self.name,
            applicantClass,
            applicantClass];

        NSError *failedToApplyThemeError = [NSError errorWithDomain:MTFErrorDomain code:MTFErrorFailedToApplyTheme userInfo:@{
            NSLocalizedDescriptionKey: description,
            MTFUnappliedPropertiesErrorKey: unappliedValuesByProperties,
            MTFThemeClassNameErrorKey: self.name,
            MTFApplicantErrorKey: applicantInstance,
        }];

        if (error != NULL) {
            *error = failedToApplyThemeError;
        }

        if (logFailures) {
            NSLog(@"Motif: Theme class application failed: %@", failedToApplyThemeError);
        }

        return NO;
    }

    // If any of the appliers or transformers produced an error, application was
    // unsuccessful.
    if (propertiesWithErrors.count > 0) {
        if (error == NULL && !logFailures) return NO;

        NSMutableDictionary *valuesByPropertiesWithErrors = [NSMutableDictionary dictionary];
        for (NSString *property in propertiesWithErrors) {
            valuesByPropertiesWithErrors[property] = self.properties[property];
        }

        NSString *description = [NSString stringWithFormat:
            @"Failed to apply theme class properties %@ from the theme class "\
                "named '%@' to an instance of %@.",
            [propertiesWithErrors.allObjects componentsJoinedByString:@", "],
            self.name,
            applicantClass];

        NSError *failedToApplyThemeError = [NSError errorWithDomain:MTFErrorDomain code:MTFErrorFailedToApplyTheme userInfo:@{
            NSLocalizedDescriptionKey: description,
            MTFUnappliedPropertiesErrorKey: valuesByPropertiesWithErrors,
            MTFThemeClassNameErrorKey: self.name,
            MTFUnderlyingErrorsErrorKey: errors,
            MTFApplicantErrorKey: applicantInstance,
        }];

        if (error != NULL) {
            *error = failedToApplyThemeError;
        }

        if (logFailures) {
            NSLog(@"Motif: Theme class application failed: %@", failedToApplyThemeError);
        }

        return NO;
    }

    if (isClass) {
        [applicantClass mtf_setThemeClass:self];
    }
    else {
        [applicantInstance mtf_setThemeClass:self];
    }
    
    return YES;
}

#pragma mark Private

- (BOOL)isEqualToThemeClass:(MTFThemeClass *)themeClass {
    if (themeClass == nil) return NO;

    BOOL haveEqualNames = [self.name isEqualToString:themeClass.name];

    BOOL haveEqualPropertiesConstants = [self.propertiesConstants isEqual:themeClass.propertiesConstants];

    return (
        haveEqualNames
        && haveEqualPropertiesConstants
    );
}

- (void)setPropertiesConstants:(NSDictionary<NSString *,MTFThemeConstant *> *)propertiesConstants {
    NSParameterAssert(propertiesConstants != nil);

    _propertiesConstants = propertiesConstants;
    _resolvedPropertiesConstants = [self createResolvedPropertiesConstantsFromPropertiesConstants:_propertiesConstants];
    _properties = [self createPropertiesFromResolvedPropertiesConstants:_resolvedPropertiesConstants];
}

- (NSDictionary<NSString *, MTFThemeConstant *> *)createResolvedPropertiesConstantsFromPropertiesConstants:(NSDictionary<NSString *, MTFThemeConstant *> *)propertiesConstants {
    NSParameterAssert(propertiesConstants != nil);

    NSMutableDictionary<NSString *, MTFThemeConstant *> *resolvedPropertiesConstants = [NSMutableDictionary dictionary];

    [propertiesConstants enumerateKeysAndObjectsUsingBlock:^(NSString *name, MTFThemeConstant *constant, BOOL *_) {
        // Resolve references to superclass into the properties constants
        // dictionary
        if (name.mtf_isSuperclassProperty) {
            MTFThemeClass *superclass = (MTFThemeClass *)constant.value;
            // In the case of the symbol generator, the superclasses could
            // not be resolved, and thus may strings rather than references
            if ([superclass isKindOfClass:MTFThemeClass.class]) {
                NSMutableDictionary<NSString *, MTFThemeConstant *> *superclassProperties = [superclass.resolvedPropertiesConstants mutableCopy];
                // Ensure that subclasses are able to override properties
                // by removing keys from the resolved properties constants
                [superclassProperties removeObjectsForKeys:propertiesConstants.allKeys];
                [resolvedPropertiesConstants addEntriesFromDictionary:superclassProperties];
            }
        } else {
            resolvedPropertiesConstants[name] = constant;
        }
    }];

    return [resolvedPropertiesConstants copy];
}

- (NSDictionary<NSString *, id> *)createPropertiesFromResolvedPropertiesConstants:(NSDictionary<NSString *, MTFThemeConstant *> *)resolvedPropertiesConstants {
    NSParameterAssert(resolvedPropertiesConstants != nil);

    NSMutableDictionary<NSString *, id> *properties = [NSMutableDictionary dictionary];

    [resolvedPropertiesConstants enumerateKeysAndObjectsUsingBlock:^(NSString *name, MTFThemeConstant *constant, BOOL *_) {
        properties[name] = constant.value;
    }];

    return [properties copy];
}

- (SEL)setterSelectorForPropertyName:(NSString*)propertyName
{
    NSString *capitalizedPropertyName = [propertyName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[propertyName substringToIndex:1] capitalizedString]];
    NSString *methodString = [NSString stringWithFormat:@"set%@:", capitalizedPropertyName];
    SEL propertySetterSelector = NSSelectorFromString(methodString);
    return propertySetterSelector;
}

- (void)setValue:(id)aValue forPropertyName:(NSString*)aPropertyName applicantClass:(Class)aClass
applicantInstance:(id)aInstance applicantIsClass:(BOOL)aIsClass
{
    // When theming normal object instances, simply use KVC
    if (!aIsClass) {
        [aInstance setValue:aValue forKey:aPropertyName];
        return;
    }
    
    // But, if we're setting the appearance of a class via its UIAppearance proxy, we can't use KVC
    SEL setterSelector = [self setterSelectorForPropertyName:aPropertyName];
    
    if ([aClass instancesRespondToSelector:setterSelector]) {
        // Args start at Index 2
        NSMethodSignature *sig = [aClass instanceMethodSignatureForSelector:setterSelector];

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
        invocation.selector = setterSelector;
        invocation.target = aInstance;
        const char *typeOfProperty = [sig getArgumentTypeAtIndex:2];
        
        if (strcmp(typeOfProperty, @encode(id)) == 0) {
            [invocation setArgument:&aValue atIndex:2];
        }
        else if (strcmp(typeOfProperty, @encode(BOOL)) == 0) {
            BOOL buf[] = { [aValue boolValue] };
            [invocation setArgument:buf atIndex:2];
        }
        else if (strcmp(typeOfProperty, @encode(int)) == 0) {
            int buf[] = { [aValue intValue] };
            [invocation setArgument:buf atIndex:2];
        }
        else if (strcmp(typeOfProperty, @encode(float)) == 0) {
            float buf[] = { [aValue floatValue] };
            [invocation setArgument:buf atIndex:2];
        }
        else if (strcmp(typeOfProperty, @encode(double)) == 0) {
            double buf[] = { [aValue doubleValue] };
            [invocation setArgument:buf atIndex:2];
        }
        else if (strcmp(typeOfProperty, @encode(typeof(UIEdgeInsets))) == 0) {
            UIEdgeInsets buf[] = { [aValue UIEdgeInsetsValue] };
            [invocation setArgument:buf atIndex:2];
        }
        else { // @TODO: Any other struct types needed?
            [NSException raise:NSGenericException format:@"Unsupported property type for UIAppearance: %s", typeOfProperty];
        }
        
        [invocation invoke];
    }
}



#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;

    if (![object isKindOfClass:self.class]) return NO;

    return [self isEqualToThemeClass:object];
}

- (NSUInteger)hash {
    return (self.name.hash ^ self.propertiesConstants.hash);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ {%@: %@, %@: %@}",
        NSStringFromClass(self.class),
        NSStringFromSelector(@selector(name)), self.name,
        NSStringFromSelector(@selector(properties)), self.properties
    ];
}

@end

NS_ASSUME_NONNULL_END
