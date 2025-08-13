import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mesh: MeshSession
    @State private var currentRoom: String = "bitchat"
    @State private var input: String = ""
    @State private var showNetwork: Bool = false
    @State private var editingHandle: Bool = false

    var body: some View {
        ZStack(alignment: .trailing) {
            mainChat
            if showNetwork { networkPanel.transition(.move(edge: .trailing)) }
        }
        .animation(.easeInOut(duration: 0.2), value: showNetwork)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .onAppear { mesh.start(room: currentRoom) }
    }

    var mainChat: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(currentRoom)")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                if editingHandle {
                    TextField("@handle", text: $mesh.nickname, onCommit: {
                        mesh.updateNickname(mesh.nickname)
                        editingHandle = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                } else {
                    Text("\(mesh.nickname)")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.green)
                        .onTapGesture { editingHandle = true }
                }
                Button(action: { showNetwork.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(mesh.nearbyCount)")
                    }
                    .foregroundColor(mesh.nearbyCount > 0 ? .green : .red)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().background(Color.green.opacity(0.5))

            ScrollViewReader { proxy in
                ScrollView { messagesList }
                    .onChange(of: mesh.messages.count) { _ in
                        if let last = mesh.messages.last?.id {
                            withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                        }
                    }
            }

            inputBar
        }
    }

    var messagesList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(mesh.messages) { msg in
                MessageRow(message: msg)
                    .id(msg.id)
            }
        }
        .padding(.horizontal)
    }

    var inputBar: some View {
        HStack(spacing: 8) {
            TextField("type a message…", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    var networkPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NETWORK")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Button(action: { showNetwork = false }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.green)
                }
            }
            Divider().background(Color.green.opacity(0.5))
            if mesh.nearbyHandles.isEmpty {
                Text("nobody around…")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
            } else {
                ForEach(mesh.nearbyHandles, id: \.self) { handle in
                    Button(handle) {
                        // For MVP tapping a handle just closes panel; chat is broadcast in the room
                        showNetwork = false
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
        }
        .padding()
        .frame(width: 260)
        .background(Color.black.opacity(0.98))
        .overlay(Rectangle().fill(Color.green.opacity(0.2)).frame(width: 1), alignment: .leading)
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        mesh.send(text: text, room: currentRoom)
        input = ""
    }
}

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("[\(message.timeString)] * \(message.sender) *")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Text(message.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.green)
        }
    }
}
