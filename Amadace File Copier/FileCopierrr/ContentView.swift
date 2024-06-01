import SwiftUI
import AppKit

struct ContentView: View {
    @State private var sourceURLs: [URL] = []
    @State private var destinationURL: URL?
    @State private var transferProgress: Double = 0.0
    @State private var statusMessage: String = "Please select file(s) and a destination."
    @State private var isSelectingDestination = false
    @State private var transferSpeed: Double = 0.0
    @State private var transferredSize: Double = 0
    @State private var totalSize: Int64 = 0
    @State private var eta: TimeInterval = 0
    @State private var isTransferInProgress = false
    @State private var showByAmadacePopover = false
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Select File(s)") {
                selectFiles()
            }
            
            Button("Select Destination") {
                isSelectingDestination = true
            }
            
            Button(isTransferInProgress ? "Cancel Transfer & Quit" : "Start Copy") {
                if isTransferInProgress {
                    cancelTransfer()
                } else {
                    startCopy()
                }
            }
            .disabled(sourceURLs.isEmpty || destinationURL == nil)
            
            ProgressView(value: transferProgress, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 300)
            
            Text(String(format: "Progress: %.2f%%", transferProgress))
            Text(String(format: "Transferred: %.2f MB / %.2f MB", transferredSize, Double(totalSize) / (1024 * 1024)))
            Text(String(format: "Transfer Speed: %.2f KB/s", transferSpeed))
            Text(formatETA(eta: eta))
            Text(statusMessage)
                .foregroundColor(transferProgress == 100 ? .green : .red) // Color text based on success/failure
            
            Spacer()
            
            Button("Clear Inputs") {
                reset()
            }
            .disabled(isTransferInProgress)
            
            // ♠ button
            HStack {
                Spacer()
                Button(action: {
                    showByAmadacePopover.toggle()
                }) {
                    Text("♠")
                        .font(.system(size: 20))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showByAmadacePopover, content: {
                    Text("\n     By Amadace | v1.1 \n     Open Source project @ https://github.com/Amadace     \n")
                })
            }
        }
        .padding()
        .fileImporter(isPresented: $isSelectingDestination, allowedContentTypes: [.folder]) { result in
            if case .success(let selectedURL) = result {
                print("Destination selected: \(selectedURL)")
                destinationURL = selectedURL
                statusMessage = "Destination selected: \(selectedURL.path)"
            } else {
                print("Error selecting destination.")
            }
        }
    }
    
    func selectFiles() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = ["public.item"]
        
        if openPanel.runModal() == .OK {
            sourceURLs = openPanel.urls
            if let firstURL = sourceURLs.first {
                print("Files selected: \(sourceURLs)")
                statusMessage = "Files selected: \(sourceURLs.count)"
                totalSize = sourceURLs.map { (try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? Int64) ?? 0 }.reduce(0, +)
            }
        }
    }
    
    func startCopy() {
        guard !sourceURLs.isEmpty, let destinationURL = destinationURL else {
            statusMessage = "Please select files and a destination."
            return
        }
        
        // Capture destination path
        let destinationPath = destinationURL.path
        
        isTransferInProgress = true
        
        // Use a concurrent queue for copying files
        let transferQueue = DispatchQueue(label: "fileTransferQueue", attributes: .concurrent)
        let group = DispatchGroup()
        
        for sourceURL in sourceURLs {
            transferQueue.async(group: group) {
                let destinationFileURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
                do {
                    var bytesCopied: Int64 = 0
                    let startTime = Date()
                    
                    let bufferSize = 1024 * 1024 // 1 MB buffer size
                    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                    
                    let input = InputStream(url: sourceURL)
                    let output = OutputStream(url: destinationFileURL, append: false)
                    
                    input?.open()
                    output?.open()
                    
                    defer {
                        input?.close()
                        output?.close()
                        buffer.deallocate()
                    }
                    
                    while input!.hasBytesAvailable {
                        let bytesRead = input!.read(buffer, maxLength: bufferSize)
                        if bytesRead < 0 {
                            throw input!.streamError!
                        }
                        bytesCopied += Int64(bytesRead)
                        DispatchQueue.main.async {
                            transferredSize += Double(bytesRead) / (1024 * 1024) // Convert bytes to MB
                            transferProgress = Double(transferredSize) / (Double(totalSize) / (1024 * 1024)) * 100.0
                            
                            let timeElapsed = Date().timeIntervalSince(startTime)
                            if timeElapsed > 0 {
                                transferSpeed = transferredSize / timeElapsed * 1024 // in KB/s
                                let remainingSize = Double(totalSize) - transferredSize * 1024 * 1024 // in bytes
                                let updatedEta = remainingSize / (transferSpeed * 1024.0) // Calculate ETA in seconds
                                
                                eta = updatedEta
                            }
                        }
                        
                        output?.write(buffer, maxLength: bytesRead)
                    }
                    
                    DispatchQueue.main.async {
                        statusMessage = "File \(sourceURL.lastPathComponent) copied successfully to \(destinationPath)."
                    }
                } catch {
                    DispatchQueue.main.async {
                        statusMessage = "Failed to copy file \(sourceURL.lastPathComponent): \(error.localizedDescription)"
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            isTransferInProgress = false
            transferProgress = 100
        }
    }
    
    func cancelTransfer() {
        // Implement cancellation logic here if needed
        // For simplicity, just reset the UI
        statusMessage = "Transfer canceled."
        isTransferInProgress = false
        exit(0)
    }
    
    func formatETA(eta: TimeInterval) -> String {
        var formattedETA = "ETA: "
        
        if eta < 60 {
            formattedETA += "\(Int(eta)) seconds"
        } else if eta < 3600 {
            let minutes = Int(eta / 60)
            let seconds = Int(eta.truncatingRemainder(dividingBy: 60))
            formattedETA += "\(minutes) minutes, \(seconds) seconds"
        } else {
            let hours = Int(eta / 3600)
            let minutes = Int((eta.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(eta.truncatingRemainder(dividingBy: 60))
            formattedETA += "\(hours) hours, \(minutes) minutes, \(seconds) seconds"
        }
        
        return formattedETA
    }
    
    func reset() {
        sourceURLs.removeAll()
        destinationURL = nil
        totalSize = 0
        transferredSize = 0
        transferProgress = 0
        transferSpeed = 0
        eta = 0
        statusMessage = ""
        isSelectingDestination = false
        isTransferInProgress = false
    }
}
