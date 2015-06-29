import Motif

protocol ThemeApplicable {
    // The ideal swift API
    static func registerThemePropertyApplier<T>(property: String, applier: (object: NSObject, value: T) -> Void) -> MTFThemeClassApplicable?

    // The old janky Obj-C API, copied from Motif.NSObject_ThemeClassAppliers
    static func mtf_registerThemeProperty(property: String, requiringValueOfClass valueClass: AnyClass, applierBlock: (AnyObject, AnyObject) -> Void) -> MTFThemeClassApplicable
}

extension ThemeApplicable {
    static func registerThemePropertyApplier<T>(property: String, applier: (object: Self, value: T) -> Void) -> MTFThemeClassApplicable? {
        let propertyValueType = T.self
        print("\(property): \(propertyValueType)")

        // ... is this the only way to check if something is of a C type?
        let isCType = String("\(propertyValueType)").hasPrefix("C.")
        print(isCType)
        if isCType {
            // How on earth are we going to get this to match the results
            // of an @encode directive?

            return nil
        }

        // Is there any way to unwrap an optional that's passed in here?

        let passthrough = propertyValueType as! NSObject.Type

        print(passthrough)

        return self.mtf_registerThemeProperty(property, requiringValueOfClass: passthrough, applierBlock: { (propertyValue, objectToTheme) -> Void in

            print("\(objectToTheme), \(propertyValue)")

            if
                let objectToTheme = objectToTheme as? Self,
                let propertyValue = propertyValue as? T {
                    print("\(objectToTheme)")
                    print("\(propertyValue)")
                    applier(object: objectToTheme, value: propertyValue)
            }
        })
    }
}

extension NSObject: ThemeApplicable {}

UIView.registerThemePropertyApplier("backgroundColor") { (object, value: UIColor) in
    object.backgroundColor = value
}

//UIButton.registerThemePropertyApplier("contentEdgeInsets") { $0.contentEdgeInsets = $1 }

var error: NSError?
let themeDictionary = [
    ".Class": [
        "backgroundColor": "#000000"
    ]
]

let theme = MTFTheme(themeDictionary: themeDictionary, error: &error)
assert(error == nil)

let object = UIView()
let success = theme.applyClassWithName("Class", toObject: object)

print(object.backgroundColor)
