import SwiftUI

struct ContentView: View {
    @StateObject private var model = DashboardViewModel()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            DashboardView(model: model)
                .preferredColorScheme(.dark)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }
}

#Preview {
    ContentView()
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.15),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 18) {
                Image(systemName: "curlybraces.square")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Seditor")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Swift-crafted playground for the web.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .ignoresSafeArea()
    }
}
