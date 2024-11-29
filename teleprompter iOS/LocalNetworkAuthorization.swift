import Foundation
import Network

@available(iOS 14.0, *)
public class LocalNetworkAuthorization: NSObject {
    private var browser: NWBrowser?
    private var completion: ((Bool) -> Void)?
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        
        // Create parameters
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // Browse for our service type
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(
                type: "_teleprompter._tcp",
                domain: "local."
            ),
            using: parameters
        )
        self.browser = browser
        
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Local network access granted")
                self?.completion?(true)
                self?.browser?.cancel()
            case .failed(let error):
                print("Local network access failed: \(error)")
                self?.completion?(false)
                self?.browser?.cancel()
            case .waiting(let error):
                print("Local network access waiting: \(error)")
            case .cancelled:
                print("Local network browser cancelled")
            default:
                break
            }
        }
        
        print("Starting local network authorization check...")
        browser.start(queue: .main)
    }
}
