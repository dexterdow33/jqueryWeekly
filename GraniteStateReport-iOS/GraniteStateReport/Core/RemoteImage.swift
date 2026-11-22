import SwiftUI
import UIKit

/// Loads and caches images. Memory cache for scrolling, URLCache on disk for the next launch.
actor ImagePipeline {
    static let shared = ImagePipeline()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024,
                                          diskCapacity: 256 * 1024 * 1024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
        memory.countLimit = 150
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached
        }
        if let running = inFlight[url] {
            return await running.value
        }
        let session = self.session
        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
                  let image = UIImage(data: data)
            else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            memory.setObject(image, forKey: url as NSURL)
        }
        return image
    }
}

/// An image from the network that fills whatever frame it is given.
/// Size it from outside with `.aspectRatio` or `.frame`.
struct RemoteImage: View {
    let url: URL?

    @State private var image: UIImage?
    @State private var loadedURL: URL?

    var body: some View {
        Color.gsrPlaceholder
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: url) {
                // A row scrolling back into view keeps the picture it already has.
                if loadedURL == url, image != nil { return }
                image = nil
                loadedURL = nil
                guard let url else { return }
                let loaded = await ImagePipeline.shared.image(for: url)
                guard !Task.isCancelled else { return }
                loadedURL = url
                withAnimation(.easeOut(duration: 0.2)) {
                    image = loaded
                }
            }
            .accessibilityHidden(true)
    }
}
