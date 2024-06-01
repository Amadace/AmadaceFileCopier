import SwiftUI
import AppKit

struct FilePicker: NSViewControllerRepresentable {
    var allowedFileTypes: [String]?
    var onPicked: ((URL) -> Void)
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }
    
    func makeNSViewController(context: Context) -> NSViewController {
        NSViewController()
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = allowedFileTypes
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.begin { result in
            if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                guard let url = openPanel.url else { return }
                context.coordinator.onPicked(url)
            }
        }
    }
    
    class Coordinator: NSObject {
        var onPicked: ((URL) -> Void)
        
        init(onPicked: @escaping ((URL) -> Void)) {
            self.onPicked = onPicked
        }
    }
}
