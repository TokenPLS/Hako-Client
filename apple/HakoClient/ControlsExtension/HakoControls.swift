import AppIntents
import SwiftUI
import WidgetKit

@main
struct HakoControlsBundle: WidgetBundle {
    var body: some Widget {
        HakoMainWidget()
         
         
        if #available(iOS 18.0, *) {
            HakoVPNControl()
        }
    }
}

@available(iOS 18.0, *)
struct HakoVPNControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: HakoSystemHandoff.controlKind,
            provider: Provider()
        ) { active in
            ControlWidgetToggle(
                "Clash VPN",
                isOn: active,
                action: HakoVPNControlIntent()
            ) { isOn in
                 
                 
                 
                 
                Label(
                    isOn ? "Connected" : "Disconnected",
                    image: HakoSystemHandoff.controlSymbolName
                )
            }
        }
        .displayName("Clash VPN")
        .description("Start or stop the installed Clash by Hako VPN profile.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
             
             
             
             
             
             
             
             
            if let live = await HakoVPNControlDriver.isActive() { return live }
            return HakoSystemHandoff().isVPNSnapshotActive
        }
    }
}
