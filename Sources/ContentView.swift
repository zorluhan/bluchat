import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mesh: MeshSession
    @State private var currentRoom: String = "bitchat"
    @State private var input: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(currentRoom)")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.green)
                Spacer()
                Text("@\(mesh.nickname)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().background(Color.green.opacity(0.5))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(mesh.messages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: mesh.messages.count) { _ in
                    if let last = mesh.messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

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
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .onAppear { mesh.start(room: currentRoom) }
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
