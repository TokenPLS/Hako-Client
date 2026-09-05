import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoProfileCollectionPage<
    Icon: View,
    Content: View
>: View {
    public let profileName: String
    public let message: HakoDisplayText

    private let icon: Icon
    private let content: Content

    public init(
        profileName: String,
        message: HakoDisplayText,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content
    ) {
        self.profileName = profileName
        self.message = message
        self.icon = icon()
        self.content = content()
    }

    public var body: some View {
#if os(macOS)
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        Form {
            Section {
                HakoProfileContextHeader(
                    profileName: profileName,
                    message: message
                ) {
                    icon
                }
            }

            content
        }
#else
        Form {
            Section {
                HakoProfileContextHeader(
                    profileName: profileName,
                    message: message
                ) {
                    icon
                }
            }

            content
        }
#endif
    }
}
