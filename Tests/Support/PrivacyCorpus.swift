/// Labeled corpus for the on-device "is this personal?" classifier.
/// Sentences avoid the gate's phrase/word lists on purpose: they exercise the classifier itself.
enum PrivacyCorpus {
    /// Self-referential and personal. Must stay on device.
    static let personal: [(category: String, text: String)] = [
        ("names", "Can you tell me if Sarah Johnson replied to me yet"),
        ("names", "Remind me what David Chen said to us at lunch"),
        ("names", "Draft a reply to Priya Patel for me about the weekend"),
        ("health", "I keep waking up at 3am with my heart racing"),
        ("health", "my knee has been swollen since the run on sunday"),
        ("health", "Should I be worried about the rash on my arm"),
        ("health", "my blood sugar readings have been high all week"),
        ("finance", "my rent went up again and I can't cover it"),
        ("finance", "how much of my paycheck should go to savings"),
        ("finance", "I owe my brother a lot and don't know how to repay him"),
        ("location", "my neighbourhood feels unsafe walking home at night"),
        ("location", "how long does it take me to get to our flat from the station"),
        ("contacts", "who should I call first from my list when something goes wrong"),
        ("contacts", "send my mum the number for the plumber"),
        ("relationships", "my girlfriend and I keep arguing about moving in"),
        ("relationships", "my dad hasn't spoken to me since the wedding"),
        ("emotions", "I feel so lonely since we moved here"),
        ("emotions", "everything about my life feels overwhelming right now"),
        ("work", "my manager keeps taking credit for my work"),
        ("work", "should I tell my team I'm interviewing elsewhere")
    ]

    /// Self-referential but impersonal (tasks about the owner's code, writing, study).
    /// These are the hard negatives: false positives here only cost a cloud fallback.
    static let impersonalSelfReferential: [String] = [
        "Rewrite my Swift function to use async await",
        "why does my for loop never terminate",
        "make my essay on the French Revolution more concise",
        "check my maths: is 17 times 23 equal to 391",
        "translate my sentence into Spanish: the library opens at nine",
        "help me understand how photosynthesis works",
        "give me three ideas for a science fair project about magnets",
        "explain to me the difference between TCP and UDP",
        "my SQL query returns duplicate rows, how do I fix it",
        "quiz me on the capitals of South America"
    ]

    /// No self-reference at all. Must never be flagged by the classifier.
    static let impersonal: [String] = [
        "What is the capital of Peru?",
        "How do I sort an array in Swift?",
        "Explain actors in Swift concurrency",
        "Summarize the causes of the First World War",
        "What year did Apollo 11 land on the moon",
        "Convert 30 degrees Celsius to Fahrenheit",
        "List the planets in order from the sun",
        "Write a haiku about autumn leaves",
        "Compare Python and Rust for command line tools",
        "How does a heat pump work"
    ]
}
