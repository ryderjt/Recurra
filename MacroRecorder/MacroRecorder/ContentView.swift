import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = RecordManager()
    @StateObject private var replayer = ReplayManager()

    var body: some View {
        VStack(spacing: 16) {
            Text("Macro Recorder")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Capture and replay your keyboard and mouse actions with ease.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                Button(action: toggleRecording) {
                    Text(recorder.isRecording ? "Stop Recording" : "Record")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)

                Button(action: replayer.replay) {
                    Text("Replay")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .disabled(recorder.recordedEvents.isEmpty)
            }
        }
        .padding(40)
        .frame(minWidth: 420, minHeight: 280)
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stopRecording()
        } else {
            recorder.startRecording()
        }
    }
}

#Preview {
    ContentView()
}
