import Foundation

public struct Template: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var text: String

    public init(id: UUID = UUID(), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }

    // Fixed IDs so preset references survive re-installation.
    public static let builtIns: [Template] = [
        Template(id: UUID(uuidString: "B5E7B3A0-0001-4000-8000-000000000001")!,
                 name: "Review Code",
                 text: "Review this code. Point out bugs, design issues, and concrete improvements."),
        Template(id: UUID(uuidString: "B5E7B3A0-0001-4000-8000-000000000002")!,
                 name: "Find Security Vulnerabilities",
                 text: "Find security vulnerabilities in this code. For each, explain the risk and how to fix it."),
        Template(id: UUID(uuidString: "B5E7B3A0-0001-4000-8000-000000000003")!,
                 name: "Explain Architecture",
                 text: "Explain the architecture of this project: main components, how they interact, and the key design decisions."),
        Template(id: UUID(uuidString: "B5E7B3A0-0001-4000-8000-000000000004")!,
                 name: "Refactor",
                 text: "Refactor this project. Identify duplication, poor abstractions, and unnecessary complexity, and propose specific changes."),
        Template(id: UUID(uuidString: "B5E7B3A0-0001-4000-8000-000000000005")!,
                 name: "Write Documentation",
                 text: "Write documentation for this project: an overview, setup instructions, and API/usage documentation."),
    ]
}

/// A named bundle of options — the "Favorites" feature.
public struct Preset: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var mode: OutputMode
    public var format: OutputFormat
    public var includeGlobs: [String]
    public var excludeGlobs: [String]
    public var limits: Limits?
    public var templateID: UUID?

    public init(id: UUID = UUID(), name: String, mode: OutputMode = .auto,
                format: OutputFormat = .markdown, includeGlobs: [String] = [],
                excludeGlobs: [String] = [], limits: Limits? = nil, templateID: UUID? = nil) {
        self.id = id
        self.name = name
        self.mode = mode
        self.format = format
        self.includeGlobs = includeGlobs
        self.excludeGlobs = excludeGlobs
        self.limits = limits
        self.templateID = templateID
    }

    public static let builtIns: [Preset] = [
        Preset(id: UUID(uuidString: "B5E7B3A0-0002-4000-8000-000000000001")!,
               name: "Python Project", includeGlobs: ["*.py", "*.md", "*.toml", "*.cfg", "*.ini", "*.txt"]),
        Preset(id: UUID(uuidString: "B5E7B3A0-0002-4000-8000-000000000002")!,
               name: "LaTeX Paper", includeGlobs: ["*.tex", "*.bib", "*.sty", "*.cls", "*.md"]),
        Preset(id: UUID(uuidString: "B5E7B3A0-0002-4000-8000-000000000003")!,
               name: "Web Project",
               includeGlobs: ["*.js", "*.jsx", "*.ts", "*.tsx", "*.html", "*.css", "*.scss", "*.json", "*.md"],
               excludeGlobs: ["package-lock.json", "*.min.js", "*.min.css"]),
        Preset(id: UUID(uuidString: "B5E7B3A0-0002-4000-8000-000000000004")!,
               name: "Configuration Files",
               includeGlobs: ["*.json", "*.yaml", "*.yml", "*.toml", "*.ini", "*.conf", "*.env.example"]),
    ]
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var defaultFormat: OutputFormat
    public var defaultPathMode: PathMode
    public var respectGitignore: Bool
    public var respectLlmignore: Bool
    public var ignoreRules: [String]
    public var limits: Limits
    public var extraTextExtensions: [String]
    public var charsPerToken: Double
    public var showNotification: Bool
    public var extraction: ExtractionSettings
    public var templates: [Template]
    public var presets: [Preset]
    public var defaultTemplateID: UUID?
    public var defaultPresetID: UUID?

    public init() {
        defaultFormat = .markdown
        defaultPathMode = .absolute
        respectGitignore = true
        respectLlmignore = true
        ignoreRules = DefaultIgnoreRules.standard
        limits = .standard
        extraTextExtensions = []
        charsPerToken = 4
        showNotification = true
        extraction = ExtractionSettings()
        templates = Template.builtIns
        presets = Preset.builtIns
        defaultTemplateID = nil
        defaultPresetID = nil
    }

    // Tolerant decoding: new fields fall back to defaults so old settings files keep working.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        defaultFormat = (try? c.decode(OutputFormat.self, forKey: .defaultFormat)) ?? d.defaultFormat
        defaultPathMode = (try? c.decode(PathMode.self, forKey: .defaultPathMode)) ?? d.defaultPathMode
        respectGitignore = (try? c.decode(Bool.self, forKey: .respectGitignore)) ?? d.respectGitignore
        respectLlmignore = (try? c.decode(Bool.self, forKey: .respectLlmignore)) ?? d.respectLlmignore
        ignoreRules = (try? c.decode([String].self, forKey: .ignoreRules)) ?? d.ignoreRules
        limits = (try? c.decode(Limits.self, forKey: .limits)) ?? d.limits
        extraTextExtensions = (try? c.decode([String].self, forKey: .extraTextExtensions)) ?? d.extraTextExtensions
        charsPerToken = (try? c.decode(Double.self, forKey: .charsPerToken)) ?? d.charsPerToken
        showNotification = (try? c.decode(Bool.self, forKey: .showNotification)) ?? d.showNotification
        extraction = (try? c.decode(ExtractionSettings.self, forKey: .extraction)) ?? d.extraction
        templates = (try? c.decode([Template].self, forKey: .templates)) ?? d.templates
        presets = (try? c.decode([Preset].self, forKey: .presets)) ?? d.presets
        defaultTemplateID = try? c.decode(UUID.self, forKey: .defaultTemplateID)
        defaultPresetID = try? c.decode(UUID.self, forKey: .defaultPresetID)
    }

    public func template(id: UUID?) -> Template? {
        guard let id else { return nil }
        return templates.first { $0.id == id }
    }

    public var ignoreConfiguration: IgnoreConfiguration {
        IgnoreConfiguration(
            excludeGlobs: [], includeGlobs: [],
            respectGitignore: respectGitignore,
            respectLlmignore: respectLlmignore,
            defaultRules: ignoreRules
        )
    }

    /// Builds the effective request for a Quick Action invocation.
    public func request(roots: [URL], mode: OutputMode, preset: Preset? = nil) -> CopyRequest {
        var ignore = ignoreConfiguration
        var limits = self.limits
        var format = defaultFormat
        var template = self.template(id: defaultTemplateID)?.text
        var effectiveMode = mode
        if let preset {
            ignore.includeGlobs = preset.includeGlobs
            ignore.excludeGlobs = preset.excludeGlobs
            if let presetLimits = preset.limits { limits = presetLimits }
            format = preset.format
            if let text = self.template(id: preset.templateID)?.text { template = text }
            if mode == .auto { effectiveMode = preset.mode }
        }
        return CopyRequest(
            roots: roots, mode: effectiveMode, format: format, pathMode: defaultPathMode,
            template: template, ignore: ignore, limits: limits,
            extraTextExtensions: Set(extraTextExtensions.map { $0.lowercased() }),
            charsPerToken: charsPerToken, extraction: extraction
        )
    }
}
