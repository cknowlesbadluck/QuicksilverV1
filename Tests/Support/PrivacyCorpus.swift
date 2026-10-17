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

    /// Held out: written after the domain lexicon was frozen and never used to tune it.
    /// The tests record honest generalisation on these, including known misses.
    static let heldOutPersonal: [String] = [
        "my sister just got engaged and I don't know what to get her",
        "I think my landlord is going to evict us",
        "how do I tell my parents I'm dropping out",
        "my toddler won't eat anything green",
        "is it normal that my hands shake every morning",
        "we can't afford the car repairs this month",
        "my credit card got declined at the shop",
        "our cat has been sick for days",
        "remind me to pay the electricity bill on friday",
        "my coworker keeps making comments about my weight",
        "I'm nervous about my driving test tomorrow",
        "my husband snores and I can't sleep"
    ]

    static let heldOutImpersonalSelfReferential: [String] = [
        "my unit tests fail only on CI, any idea why",
        "convert my recipe from cups to grams",
        "why is my React component rendering twice",
        "summarize my notes on the Krebs cycle",
        "my python script is slow, how can I profile it",
        "teach me the basics of chess openings",
        "can you rate my haiku about the sea",
        "show me how to center a div",
        "explain my compiler error: missing return in closure",
        "give me a mnemonic for the order of the planets"
    ]
}
