import NetworkExtension

 
 
 
class PacketTunnelProvider: NEPacketTunnelProvider {
    private lazy var provider = ExtensionProvider(tunnelProvider: self)

    override func startTunnel(options _: [String: NSObject]?) async throws {
        try await provider.start()
        #if os(iOS) || os(macOS)
         
        provider.widgetMailbox.start()
        #endif
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        #if os(iOS) || os(macOS)
         
         
        provider.widgetMailbox.stop()
        #endif
        await provider.stop(reason: reason)
    }

    override func sleep() async {
        provider.sleep()
    }

    override func wake() {
        provider.wake()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        Task {
            let (reply, afterReply) = await provider.handleMessage(messageData)
            completionHandler?(reply)
            afterReply?()
        }
    }
}
