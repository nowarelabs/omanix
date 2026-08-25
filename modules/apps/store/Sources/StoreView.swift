// modules/apps/store/Sources/StoreView.swift
// Omanix Store — package management view
// Calls lib/omanix-add.sh helpers for structured configuration.nix edits
import SwiftUI

struct StoreView: View {
    @State private var isInstalling = false
    @State private var installProgress: Double = 0
    @State private var installError: String?

    var body: some View {
        VStack(spacing: 16) {
            if isInstalling {
                ProgressView("Installing...", value: installProgress, total: 1.0)
                    .progressViewStyle(.linear)
            }

            if let error = installError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Rollback") {
                        rollback()
                    }
                    Button("Retry") {
                        installError = nil
                    }
                }
                .padding()
                .background(.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }

    func install(package: String) {
        isInstalling = true
        installProgress = 0.5
        // TODO: Call lib/omanix-add.sh via Process
        // Show diff preview before rebuild
        // Run nix flake check dry
        // Run omanix rebuild with progress
        isInstalling = false
    }

    func rollback() {
        // TODO: Call darwin-rebuild --rollback via Process
        installError = nil
    }
}

#Preview {
    StoreView()
}
