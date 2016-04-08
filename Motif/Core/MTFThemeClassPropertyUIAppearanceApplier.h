//
//  MTFThemeClassPropertyUIAppearanceApplier.h
//  Pods
//
//  Created by Mark Kirk on 4/1/16.
//
//

#import <Motif/MTFThemeClassApplicable.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTFThemeClassPropertyUIAppearanceApplier : NSObject<MTFThemeClassApplicable>

@property (nonatomic, copy, readonly) NSString *property;
@property (nonatomic, copy, readonly) NSSet<NSString *> *properties;
@property (nonatomic, copy, readonly) MTFThemePropertyUIAppearanceApplierBlock applierBlock;
@property (readonly, nonatomic) Class valueClass;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithProperty:(NSString *)property
                      valueClass:(Class)valueClass
                    applierBlock:(MTFThemePropertyUIAppearanceApplierBlock)applierBlock NS_DESIGNATED_INITIALIZER;


+ (nullable NSDictionary<NSString *, id> *)valueForApplyingProperty:(NSString *)property asClass:(Class)valueClass fromThemeClass:(MTFThemeClass *)themeClass error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END


