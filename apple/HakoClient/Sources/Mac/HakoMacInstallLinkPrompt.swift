import Foundation

 
 
 
 
 
 
 
 
 
 
 
struct HakoMacInstallLinkPrompt {
     
     
     
    let pending: String

    init(pending: String) {
        self.pending = pending
    }

     
     
     
    var isLocalConfiguration: Bool {
        FlClashInstallLink.isLocalOrigin(pending)
    }

    var title: String {
        isLocalConfiguration ? "Add this configuration?" : "Add this subscription?"
    }

     
    var lead: String {
        isLocalConfiguration
            ? "A link wants to add a configuration to Clash.\n\n"
            : "A link wants to add a subscription to Clash.\n\n"
    }

     
    var link: String {
        ProfileImportRouter.confirmationText(for: pending)
    }

     
    var message: String {
        lead + link
    }

     
     
     
    static let dismissalDeclines = false
}
