import SwiftUI
import VisionKit

@available(iOS 16.2, *)
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items: addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items: updatedItems)
        }

        private func handle(items: [RecognizedItem]) {
            guard let item = items.first else { return }
            if case let .barcode(barcode) = item,
               let payload = barcode.payloadStringValue {
                onScan(payload)
            }
        }
    }
}

@available(iOS 16.2, *)
extension DataScannerViewController {
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        do {
            try startScanning()
        } catch {
            assertionFailure("Failed to start scanning: \(error)")
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }
}
