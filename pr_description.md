🔒 Fix potential prompt injection in PromptBuilder

🎯 **What:**
The vulnerability was in `Services/AI/PromptBuilder.swift`, where the `assembledContext` was being appended directly to the system prompt without any clear structural separation.

⚠️ **Risk:**
If the `assembledContext` contains malicious input, it could potentially allow prompt injection attacks where the AI model executes commands hidden within the context, mistaking them for system instructions.

🛡️ **Solution:**
1. Enclosed the `assembledContext` within XML-like structural delimiters (`<context>...</context>`). This helps the model differentiate the system instructions from the active context.
2. Sanitized the input context by stripping out any `</context>` tags to prevent an attacker from escaping the context block.
3. Updated unit tests in `PromptBuilderTests.swift` to ensure these tags are present.
