import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
extension String {
    var localizedForTelevision: String {
        String(localized: String.LocalizationValue(self))
    }
}
