import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif
// Don’t import FoundationModels here — it's only available on iOS 18+

struct ContentView: View {
    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ChatView()
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
struct ChatView: View {
    @State private var promptText = ""
    @State private var aiResponse = ""
    @State private var isLoading = false

    private let lmSession = LanguageModelSession()

    var body: some View {
        VStack(spacing: 16) {
            TextField("Enter your prompt here…", text: $promptText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            Button(action: generateResponse) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Generate")
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(promptText.isEmpty)
            
            if !aiResponse.isEmpty {
                
                ScrollView {
                    Text(aiResponse)
                        .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }

    @MainActor
    private func generateResponse() {
        isLoading = true
        aiResponse = ""

        Task {
            do {
                let result = try await lmSession.respond(
                    to: promptText,
                )
                aiResponse = result.content
            } catch {
                aiResponse = "Error: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
}

