#if canImport(FoundationModels)
import FoundationModels

/// Generates short task titles from user messages using Apple's on-device Foundation Models.
actor TaskSummaryService {
    static let shared = TaskSummaryService()

    private init() {}

    /// Generate a 2-4 word title for the overall task represented by the conversation.
    /// Analyzes up to the last 5 user messages to identify the primary task, ignoring
    /// follow-up details like dates, confirmations, or clarifications.
    /// Returns nil if Foundation Models is unavailable or generation fails.
    func generateTitle(for messages: [String]) async -> String? {
        guard !messages.isEmpty else {
            print("📝 TaskSummaryService: No messages provided")
            return nil
        }
        
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("📝 TaskSummaryService: Model not available - \(availability)")
            return nil
        }

        let session = LanguageModelSession(model: .init(useCase: .general, guardrails: .permissiveContentTransformations))
        
        let numberedMessages = messages.enumerated().map { index, msg in
            "\(index + 1). \"\(msg)\""
        }.joined(separator: "\n")
        
        let prompt = """
        Analyze these user messages from a conversation with an AI assistant and identify the overall task being worked on. \
        It should read like the task that the assistant will perform based on the messages. \
        It should sound like an imperative command. Like "Verb, Adjective/Noun, Noun".

        Messages (oldest to newest):
        \(numberedMessages)

        The latest message may just be a follow-up (like a date, confirmation, or answer to a question). \
        Look at all messages to understand what the user is ultimately trying to accomplish.

        Give a short 2-4 word title for the overall task, not just the latest message. \
        Make the title specific to the details in the message. Dont use generic nouns. \
        Prioritise proper nouns and details that the user has sent.

        It is crucial that the title is succinct because it will be used in UI. Only output the title, nothing else.
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Convert an intent string from present/progressive tense to past tense.
    /// e.g. "Searching for files..." -> "Searched for files"
    /// Returns nil if Foundation Models is unavailable or generation fails.
    func convertToPastTense(_ intent: String) async -> String? {
        let cleaned = intent.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else { return nil }

        let session = LanguageModelSession(model: .init(useCase: .general, guardrails: .permissiveContentTransformations))

        let prompt = """
        Convert this action description to past tense. Keep the same level of detail and specificity.

        Input: "\(cleaned)"

        Rules:
        - Convert progressive/present tense to simple past tense
        - Keep proper nouns, filenames, and quoted strings unchanged
        - Keep it the same length or shorter
        - Do not add punctuation at the end

        Examples:
        - "Searching for files" → "Searched for files"
        - "Reading config.json" → "Read config.json"
        - "Browsing api.example.com" → "Browsed api.example.com"
        - "Running a command" → "Ran a command"
        - "Comparing departure times and prices" → "Compared departure times and prices"
        - "Entering passenger details" → "Entered passenger details"
        - "Writing helpers.swift" → "Wrote helpers.swift"
        - "Using browser" → "Used browser"
        - "Fetching data" → "Fetched data"
        - "Thinking" → "Thought about the task"

        Only output the converted text, nothing else.
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Generate a completion message from a task title.
    /// Transforms an imperative title like "Book train tickets" into a past-tense completion
    /// message like "Your tickets have been booked".
    /// Returns nil if Foundation Models is unavailable or generation fails.
    func generateCompletionMessage(for taskTitle: String) async -> String? {
        guard !taskTitle.isEmpty else {
            print("📝 TaskSummaryService: No task title provided")
            return nil
        }

        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            print("📝 TaskSummaryService: Model not available - \(availability)")
            return nil
        }

        let session = LanguageModelSession(model: .init(useCase: .general, guardrails: .permissiveContentTransformations))

        let prompt = """
        Transform this task title into a short completion message that tells the user the task is done.

        Task title: "\(taskTitle)"

        Rules:
        - Convert from imperative/present tense to past tense
        - Start with "Your" when appropriate (e.g., "Book train tickets" → "Your tickets have been booked")
        - Keep it concise (under 8 words)
        - Make it sound like a friendly notification
        - Do not use exclamation marks

        Examples:
        - "Book train tickets" → "Your tickets have been booked"
        - "Find restaurants nearby" → "Restaurants found nearby"
        - "Send email to John" → "Your email has been sent to John"
        - "Check weather forecast" → "Weather forecast retrieved"

        Only output the completion message, nothing else.
        """

        do {
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("📝 TaskSummaryService: Completion message generation failed - \(error)")
            return nil
        }
    }
}
#else
import Foundation

/// Fallback implementation when FoundationModels is unavailable on the build host/SDK.
actor TaskSummaryService {
    static let shared = TaskSummaryService()
    private init() {}

    func generateTitle(for messages: [String]) async -> String? { nil }
    func convertToPastTense(_ intent: String) async -> String? { nil }
    func generateCompletionMessage(for taskTitle: String) async -> String? { nil }
}
#endif
