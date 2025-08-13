import Foundation
import MultipeerConnectivity
import CryptoKit
import os.log

final class MeshSession: NSObject, ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var nickname: String
    @Published var nearbyHandles: [String] = []
    @Published var nearbyCount: Int = 0

    // Chat context
    @Published var currentRoom: String = "bitchat"
    @Published var currentDM: String? = nil  // handle when DM is active

    private let serviceType = "bluchat"
    private var myPeerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    // Discovery and routing
    private var seen: Set<String> = []
    private var discovered: Set<MCPeerID> = []
    private var handleToPeer: [String: MCPeerID] = [:]

    override init() {
        let name = UserDefaults.standard.string(forKey: "nickname") ?? MeshSession.generateNickname()
        self.nickname = name
        UserDefaults.standard.set(name, forKey: "nickname")
        myPeerID = MCPeerID(displayName: name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        super.init()
        attachDelegates()
    }

    private func attachDelegates() {
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    static func generateNickname() -> String {
        let animals = ["wolf", "eagle", "lion", "cobra", "tiger", "falcon"]
        let adj = ["swift", "silent", "green", "dark", "lucky", "wild"]
        return "@" + adj.randomElement()! + "_" + animals.randomElement()!
    }

    func start(room: String) {
        currentRoom = room
        currentDM = nil
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        post(system: "you joined #\(room)")
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func setRoom(_ room: String) {
        let cleaned = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        currentDM = nil
        currentRoom = cleaned
        post(system: "switched to #\(cleaned)")
    }

    func startDirectChat(with handle: String) {
        currentDM = handle
        post(system: "direct chat with \(handle)")
    }

    func exitDirectChat() {
        if currentDM != nil {
            currentDM = nil
            post(system: "back to #\(currentRoom)")
        }
    }

    func send(text: String, room: String? = nil) {
        let targetRoom = room ?? currentRoom
        let sender = nickname
        let msg = WireMessage.make(sender: sender, text: text, room: currentDM ?? "#" + targetRoom)
        guard let data = try? JSONEncoder().encode(msg) else { return }

        if let dmHandle = currentDM, let peer = handleToPeer[dmHandle] {
            // 1:1: send only to target peer
            try? session.send(data, toPeers: [peer], with: .reliable)
        } else {
            // Broadcast to all peers
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        relayLocally(msg)
    }

    func updateNickname(_ newNameRaw: String) {
        var newName = newNameRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.hasPrefix("@") { newName = "@" + newName }
        guard newName != nickname else { return }
        stop()
        nickname = newName
        UserDefaults.standard.set(newName, forKey: "nickname")
        myPeerID = MCPeerID(displayName: newName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        attachDelegates()
        discovered.removeAll()
        handleToPeer.removeAll()
        refreshNearby()
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        post(system: "you are now \(newName)")
    }

    private func post(system text: String) {
        let wire = WireMessage(id: UUID().uuidString, ts: Date().timeIntervalSince1970, sender: "system", room: "system", text: text)
        relayLocally(wire)
    }

    private func relayLocally(_ wire: WireMessage) {
        guard seen.insert(wire.id).inserted else { return }
        DispatchQueue.main.async {
            self.messages.append(ChatMessage.from(wire))
        }
    }

    private func refreshNearby() {
        DispatchQueue.main.async {
            self.nearbyHandles = self.discovered.map { $0.displayName }.sorted()
            self.nearbyCount = self.nearbyHandles.count
        }
    }
}

extension MeshSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            discovered.remove(peerID)
            handleToPeer[peerID.displayName] = nil
            refreshNearby()
        default:
            break
        }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let wire = try? JSONDecoder().decode(WireMessage.self, from: data) else { return }
        relayLocally(wire)
        let others = session.connectedPeers.filter { $0 != peerID }
        if !others.isEmpty { try? session.send(data, toPeers: others, with: .reliable) }
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MeshSession: MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if peerID != myPeerID {
            discovered.insert(peerID)
            handleToPeer[peerID.displayName] = peerID
            refreshNearby()
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discovered.remove(peerID)
        handleToPeer[peerID.displayName] = nil
        refreshNearby()
    }
}

// MARK: Models
struct ChatMessage: Identifiable {
    let id: String
    let time: Date
    let sender: String
    let text: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: time)
    }

    static func from(_ wire: WireMessage) -> ChatMessage {
        ChatMessage(id: wire.id, time: Date(timeIntervalSince1970: wire.ts), sender: wire.sender, text: wire.text)
    }
}

struct WireMessage: Codable {
    let id: String
    let ts: TimeInterval
    let sender: String
    let room: String  // "#room" for rooms, or "@handle" for DMs (we store it as sent)
    let text: String

    static func make(sender: String, text: String, room: String) -> WireMessage {
        WireMessage(id: UUID().uuidString, ts: Date().timeIntervalSince1970, sender: sender, room: room, text: text)
    }
}
