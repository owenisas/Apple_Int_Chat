import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif
import Playgrounds
// Don’t import FoundationModels here — it's only available on iOS 18+

struct ContentView: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ChatSessionsView()
            } else {
                Text("Foundation Models unavailable on this OS version")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

@available(iOS 26.0, *)
struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]

    static func truncatedTitle(from text: String, maxLength: Int = 32) -> String {
        guard text.count > maxLength else { return text }
        let index = text.index(text.startIndex, offsetBy: maxLength)
        return text[..<index] + "…"
    }

    init(id: UUID = UUID(), title: String? = nil, messages: [ChatMessage] = []) {
        self.id = id
        self.messages = messages
        if let title = title, !title.isEmpty {
            self.title = title
        } else if let firstText = messages.first?.text, !firstText.isEmpty {
            self.title = Self.truncatedTitle(from: firstText)
        } else {
            self.title = "New Chat"
        }
    }
}

@available(iOS 26.0, *)
struct ChatMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable { case user, ai }
    let id: UUID
    let sender: Sender
    let text: String
    init(id: UUID = UUID(), sender: Sender, text: String) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}

@available(iOS 26.0, *)
struct ChatSessionsView: View {
    @AppStorage("chat_sessions") private var sessionsData: Data = Data()
    @State private var sessions: [ChatSession] = []
    @State private var selectedSessionID: UUID?
    @State private var showingSettings = false
    @State private var quickSearchText: String = ""
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSessionID) {
                TextField("Quick Search…", text: $quickSearchText, onCommit: createQuickSearchSession)
                    .textFieldStyle(.roundedBorder)
                    .padding([.horizontal, .top])
                ForEach(sessions) { session in
                    Text(session.title.isEmpty ? "Chat " + session.id.uuidString.prefix(4) : session.title)
                        .lineLimit(1)
                        .tag(session.id)
                }
                .onDelete(perform: deleteSession)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: createSession) {
                        Label("New Chat", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            if let idx = sessions.firstIndex(where: { $0.id == selectedSessionID }) {
                ChatView(
                    session: $sessions[idx],
                    onSessionUpdate: saveSessions
                )
            } else {
                Text("Select or create a chat.")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear(perform: loadSessions)
        .onChange(of: sessions) { _, _ in saveSessions() }
        .onChange(of: selectedSessionID) { _, _ in saveSessions() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onClearHistory: clearAllSessions)
        }
    }

    private func loadSessions() {
        guard let decoded = try? JSONDecoder().decode([ChatSession].self, from: sessionsData), !decoded.isEmpty else {
            sessions = [ChatSession()]
            selectedSessionID = sessions.first?.id
            return
        }
        sessions = decoded
        selectedSessionID = sessions.first?.id
    }
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            sessionsData = data
        }
    }
    private func createSession() {
        let newSession = ChatSession()
        sessions.insert(newSession, at: 0)
        selectedSessionID = newSession.id
    }
    private func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        if let first = sessions.first {
            selectedSessionID = first.id
        } else {
            selectedSessionID = nil
        }
    }
    private func clearAllSessions() {
        sessions = []
        saveSessions()
        selectedSessionID = nil
    }
    
    private func createQuickSearchSession() {
        let trimmed = quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let systemMsg = ChatMessage(sender: .ai, text: trimmed)
        let newSession = ChatSession(messages: [systemMsg])
        sessions.insert(newSession, at: 0)
        selectedSessionID = newSession.id
        quickSearchText = ""
        saveSessions()
    }
}

@available(iOS 26.0, *)
struct ChatView: View {
    @Binding var session: ChatSession
    var onSessionUpdate: () -> Void
    @State private var promptText = ""
    @State private var isLoading = false
    private let lmSession = LanguageModelSession()
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "message")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(session.title.isEmpty ? "Chat" : session.title)
                    .font(.title2).bold()
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
            // Chat area
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(session.messages) { msg in
                        HStack {
                            if msg.sender == .ai {
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(.tint)
                                    .padding(.top, 3)
                            }
                            if msg.sender == .user { Spacer(minLength: 40) }
                            Text(msg.text)
                                .font(.body)
                                .padding(14)
                                .foregroundColor(msg.sender == .user ? .white : .primary)
                                .background(msg.sender == .user ? Color.accentColor : Color(.systemGray6))
                                .cornerRadius(16)
                                .shadow(radius: 1, x: 0, y: 1)
                            if msg.sender == .ai { Spacer(minLength: 40) }
                            if msg.sender == .user {
                                Image(systemName: "person.crop.circle")
                                    .foregroundStyle(.tint)
                                    .padding(.top, 3)
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: msg.sender == .user ? .trailing : .leading)
                    }
                    if session.messages.isEmpty {
                        HStack {
                            Spacer()
                            Text("AI responses appear here.")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 40)
            }
            .frame(maxHeight: 350)
            .padding(.horizontal)
            // User Input Area
            VStack(spacing: 12) {
                HStack {
                    TextField("Ask something…", text: $promptText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 8)
                    Button(action: generateResponse) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(promptText.isEmpty || isLoading)
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            .background(
                Color(.systemBackground)
                    .opacity(0.95)
                    .shadow(radius: 8, y: -2)
            )
        }
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
        )
    }
    @MainActor
    private func generateResponse() {
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        session.messages.append(.init(sender: .user, text: trimmed))
        onSessionUpdate()
        promptText = ""
        Task {
            do {
                let result = try await lmSession.respond(
                    to: trimmed
                )
                session.messages.append(.init(sender: .ai, text: result.content))
                onSessionUpdate()
            } catch {
                session.messages.append(.init(sender: .ai, text: "Error: \(error.localizedDescription)"))
                onSessionUpdate()
            }
            isLoading = false
        }
    }
}

@available(iOS 26.0, *)
struct SettingsView: View {
    var onClearHistory: () -> Void = {}

    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Settings")
                .font(.title2).bold()
            Text("App preferences and options will appear here.")
                .font(.body)
                .foregroundColor(.secondary)
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Text("Clear All Chat History")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 20)
            .confirmationDialog("Are you sure you want to clear all chat history? This action cannot be undone.", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear All Chat History", role: .destructive) {
                    onClearHistory()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(40)
    }
}
