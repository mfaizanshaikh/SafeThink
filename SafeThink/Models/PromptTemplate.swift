import Foundation

struct PromptTemplate: Codable, Identifiable {
    var id: String
    var name: String
    var icon: String // SF Symbol name
    var prompt: String
    var isBuiltIn: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, icon: String, prompt: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.prompt = prompt
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
    }

    static let builtIn: [PromptTemplate] = [
        PromptTemplate(name: "Summarize", icon: "doc.text", prompt: "Summarize the following text concisely:\n\n", isBuiltIn: true),
        PromptTemplate(name: "Explain Code", icon: "chevron.left.forwardslash.chevron.right", prompt: "Explain this code step by step:\n\n", isBuiltIn: true),
        PromptTemplate(name: "Fix Grammar", icon: "textformat.abc", prompt: "Fix the grammar and spelling in this text, keeping the original meaning:\n\n", isBuiltIn: true),
        PromptTemplate(name: "Translate", icon: "globe", prompt: "Translate the following text to English:\n\n", isBuiltIn: true),
        PromptTemplate(name: "Write Email", icon: "envelope", prompt: "Write a professional email about the following:\n\n", isBuiltIn: true),
        PromptTemplate(name: "Rewrite", icon: "arrow.triangle.2.circlepath", prompt: "Rewrite the following text to be clearer and more concise:\n\n", isBuiltIn: true),
    ]
}
