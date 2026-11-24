import DITranquillity
import Kingfisher
import UIKit

public protocol DependenciesConfiguration: AnyObject {
    func setup()
    func configuredContainer() -> DIContainer
}

public class DependenciesConfigurationBase: DependenciesConfiguration, Loggable {
    init() {}

    // MARK: - Configure

    public var defaultLoggingTag: LogTag {
        return .unnamed
    }

    private lazy var container: DIContainer = {
        let container = DIContainer()
        container.append(framework: AppFramework.self)
        return container
    }()

    public func configuredContainer() -> DIContainer {
        container
    }

    // MARK: - Setup

    public func setup() {
        self.setupLoader()
        self.setupModulesDependencies()
        let modifier = ImageRequestModifier(appConfig: container.resolve())
        KingfisherManager.shared.defaultOptions.append(.requestModifier(modifier))
    }

    private func setupModulesDependencies() {
        // logger
        let logger = Logger()
        let swiftyLogger = SimpleLogger()
        logger.setupLogger(swiftyLogger)
        Logger.setSharedInstance(logger)
    }

    private func setupLoader() {
        #if os(iOS)
        MRLoaderManager.configure(with: MRLoaderView.self)
        #endif
    }
}
