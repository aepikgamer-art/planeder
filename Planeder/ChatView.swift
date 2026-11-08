import SwiftUI

// MARK: - Chats list (like iMessage conversations)

struct ChatsView: View {
    @ObservedObject var store: MatchStore
    @ObservedObject var chatStore: ChatStore

    var body: some View {
        NavigationStack {
            Group {
                if store.matches.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 52)).foregroundStyle(.secondary)
                        Text("Match some planes first, then they slide in").font(.headline)
                    }
                } else {
                    List {
                        ForEach(store.matches) { match in
                            NavigationLink {
                                ChatThreadView(plane: match.plane)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(Color(hue: 0.6, saturation: 0.45, brightness: 0.35))
                                        Image(systemName: "airplane")
                                            .font(.system(size: 18, weight: .semibold))
                                            .rotationEffect(.degrees(-30))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(width: 48, height: 48)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(match.plane.reg).font(.headline)
                                        Text(chatStore.lastMessage(for: match.plane.id)?.text ?? "new match ✈️")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if match.superLiked {
                                        Image(systemName: "airplane.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                store.remove(store.matches[i])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Chats ✈️")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - One conversation with a plane

struct ChatThreadView: View {
    let plane: PlaneCard
    @ObservedObject private var chatStore = ChatStore.shared
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // plane intro header
                        VStack(spacing: 4) {
                            Image(systemName: "airplane")
                                .font(.system(size: 40, weight: .semibold))
                                .rotationEffect(.degrees(-30))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(plane.reg).font(.headline).foregroundStyle(.white)
                            Text("\(plane.airline) · \(plane.aircraft)")
                                .font(.caption).foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 10)

                        ForEach(chatStore.messages(for: plane.id)) { msg in
                            bubble(msg)
                                .id(msg.id)
                        }

                        Text("planeder can't reply — it's, like, a plane ✈️")
                            .font(.caption2.italic())
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 14)
                }
                .onChange(of: chatStore.messages(for: plane.id).count) { _, _ in
                    if let last = chatStore.messages(for: plane.id).last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Composer: you can type, the plane won't answer
            HStack(spacing: 10) {
                TextField("Message…", text: $draft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    .submitLabel(.send)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .ifAvailableGlass()
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            LinearGradient(colors: [Color(hue: 0.6, saturation: 0.4, brightness: 0.14),
                                    Color(hue: 0.75, saturation: 0.35, brightness: 0.1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 60) }
            Text(msg.text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(msg.isUser
                              ? AnyShapeStyle(Color(hue: 0.55, saturation: 0.55, brightness: 0.45))
                              : AnyShapeStyle(.ultraThinMaterial))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.5)
                )
            if !msg.isUser { Spacer(minLength: 60) }
        }
    }

    private func send() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        chatStore.send(text, to: plane)
        draft = ""
    }
}
