/// The MCP setup guide as one neo_sdui wire document — the second guide authored
/// on the same engine as how_to. Root `blocks` are the intro/detail page; `views`
/// are the per-client setup screens (chatgpt, claude, other) plus the shared faq
/// and troubleshooting screens. Every `screen:<id>` action resolves to a key in
/// `views`; the app owns the Navigator (R14). Look lives in `mcpTheme`, never on
/// the wire: no hex, no px, no fontSize, no fontFamily here.
///
/// Copy is transcribed from the Figma "MCP" screens (fileKey cqhN8078lld29kQnBjLcRo).
/// Screenshots use poster `url`s on `media` blocks; the `neo_sdui_media` add-on can
/// later point these at `.mp4`s to play inline (see how_to's note).
const mcpDocumentJson = r'''
{
  "version": 1,
  "blocks": [
    { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/hero.png", "ratio": 1.6 },
    {
      "type": "header",
      "title": "Your AI. Finally in the loop.",
      "subtitle": "Connect Neo 1 memories to ChatGPT, Claude or any AI, let it answer from your actual meetings and Neosapien Memories."
    },
    {
      "type": "header",
      "title": "Easy to setup",
      "subtitle": "One-time setup. No code. Works immediately."
    },
    {
      "type": "steps",
      "items": [
        { "caption": "Pick your AI", "detail": "ChatGPT, Claude or any other" },
        { "caption": "Follow the quick guide", "detail": "Takes less than a minute" },
        { "caption": "Ask it anything", "detail": "Neo 1 context is live" }
      ]
    },
    {
      "type": "header",
      "title": "Pick your AI",
      "subtitle": "Setup happens on your computer."
    },
    {
      "type": "card",
      "thumb": "https://cdn.neosapien.xyz/mcp/chatgpt.png",
      "title": "ChatGPT",
      "subtitle": "Web / Desktop App",
      "action": "screen:chatgpt"
    },
    {
      "type": "card",
      "thumb": "https://cdn.neosapien.xyz/mcp/claude.png",
      "title": "Claude",
      "subtitle": "Web / Desktop App / Code",
      "action": "screen:claude"
    },
    {
      "type": "card",
      "thumb": "https://cdn.neosapien.xyz/mcp/connectors.png",
      "title": "Others",
      "subtitle": "Open Connectors",
      "action": "screen:other"
    },
    {
      "type": "callout",
      "title": "Only works with AI tools that supports MCP such as Claude or ChatGPT Pro."
    },
    { "type": "code", "label": "Your MCP server", "content": "https://api.neosapien.xyz/mcp" },
    {
      "type": "header",
      "title": "Here's what it does for you",
      "subtitle": "You ask, Neo 1 recalls, your AI does the work. Things you can do:"
    },
    { "type": "card", "title": "Catch up on your day", "subtitle": "“Summarise everything I said today.”" },
    { "type": "card", "title": "Draft your replies", "subtitle": "“Write the follow up email on what I owe Subodh”" },
    { "type": "card", "title": "Prep for what's next", "subtitle": "“Prep me for my meeting with Mohit, what did he ask last time?”" },
    { "type": "card", "title": "Recall any detail", "subtitle": "“What's the medicine I discussed for my father?”" },
    { "type": "card", "title": "Turn talk into to-dos", "subtitle": "“Make a task list from my last daily standup”" },
    { "type": "card", "title": "Work across your tools", "subtitle": "“Add those tasks to my Notion.” Your AI has both Neo 1 and your other apps." },
    { "type": "card", "title": "Export data", "subtitle": "“Export all memories from yesterday as a CSV”" },
    {
      "type": "callout",
      "tone": "accent",
      "title": "Not getting results?",
      "bullets": ["Add “from NeoSapien” to your message."]
    },
    { "type": "card", "title": "Troubleshooting", "action": "screen:troubleshooting" },
    { "type": "card", "title": "FAQs", "action": "screen:faq" }
  ],
  "views": {
    "chatgpt": {
      "present": "screen",
      "blocks": [
        { "type": "header", "title": "ChatGPT MCP" },
        {
          "type": "callout",
          "tone": "accent",
          "title": "Requires laptop for setup",
          "bullets": ["Works everywhere once connected."]
        },
        {
          "type": "tabs",
          "tabs": [
            {
              "label": "Web",
              "blocks": [
                {
                  "type": "steps",
                  "items": [
                    { "caption": "Go to chatgpt.com" },
                    { "caption": "Click your profile picture" },
                    { "caption": "Select Settings" },
                    { "caption": "Click the Connected apps tab" },
                    { "caption": "Click the Add button" },
                    { "caption": "Select Model Context Protocol (MCP)" },
                    { "caption": "Add the server URL", "code": "https://api.neosapien.xyz/mcp" },
                    { "caption": "Click Advanced settings if you need to add OAuth credentials" },
                    { "caption": "Check the box: I understand and want to continue. Click Create" },
                    { "caption": "Sign in with your NeoSapien account (may differ from ChatGPT account)" },
                    { "caption": "Try your first prompt: “What do you know about me from Neosapien?”" },
                    { "caption": "Congrats! NeoSapien is now connected to ChatGPT." }
                  ]
                },
                { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/chatgpt-web.png", "ratio": 1.3333 }
              ]
            },
            {
              "label": "Desktop App",
              "blocks": [
                { "type": "text", "body": "Once connected on the web, NeoSapien works in the ChatGPT desktop app automatically — open ChatGPT and try a prompt." },
                { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/chatgpt-desktop.png", "ratio": 1.3333 }
              ]
            }
          ]
        },
        {
          "type": "callout",
          "title": "If NeoSapien MCP doesn't work or appear in the chat, do one of these:",
          "bullets": [
            "Add “from NeoSapien” to your message",
            "Close the tab and reopen ChatGPT",
            "Re-authenticate with the existing NeoSapien account",
            "Remove the NeoSapien from connectors and add it again."
          ]
        },
        { "type": "card", "title": "Troubleshooting", "action": "screen:troubleshooting" },
        { "type": "card", "title": "FAQs", "action": "screen:faq" }
      ]
    },
    "claude": {
      "present": "screen",
      "blocks": [
        { "type": "header", "title": "Claude MCP" },
        {
          "type": "callout",
          "tone": "accent",
          "title": "Requires laptop for setup",
          "bullets": ["Works everywhere once connected."]
        },
        {
          "type": "tabs",
          "tabs": [
            {
              "label": "Web",
              "blocks": [
                {
                  "type": "steps",
                  "items": [
                    { "caption": "Go to claude.ai" },
                    { "caption": "Click Customize in the left sidebar" },
                    { "caption": "Select Connectors from the menu" },
                    { "caption": "Click + then Add custom connector" },
                    { "caption": "Add the server URL", "code": "https://api.neosapien.xyz/mcp" },
                    { "caption": "Select NeoSapien from connectors list and tap “Connect” to sign in to NeoSapien account (OAuth)" },
                    { "caption": "Sign in to NeoSapien when prompted (OAuth)" },
                    { "caption": "Try your first prompt: “What do you know about me from Neosapien?”" },
                    { "caption": "Congrats! NeoSapien is now connected to Claude." }
                  ]
                },
                { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/claude-web.png", "ratio": 1.3333 }
              ]
            },
            {
              "label": "Desktop App",
              "blocks": [
                {
                  "type": "steps",
                  "items": [
                    { "caption": "Download the app from claude.ai/download" },
                    { "caption": "Click Customize in the left sidebar" },
                    { "caption": "Select Connectors from the menu" },
                    { "caption": "Click + then Add custom connector" },
                    { "caption": "Add the server URL", "code": "https://api.neosapien.xyz/mcp" },
                    { "caption": "Select NeoSapien from connectors list and tap “Connect” to sign in to NeoSapien account (OAuth)" },
                    { "caption": "Sign in to NeoSapien when prompted (OAuth)" },
                    { "caption": "Try your first prompt: “What do you know about me from Neosapien?”" },
                    { "caption": "Congrats! NeoSapien is now connected to Claude." }
                  ]
                },
                { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/claude-app.png", "ratio": 1.3333 }
              ]
            },
            {
              "label": "Code",
              "blocks": [
                {
                  "type": "steps",
                  "items": [
                    { "caption": "Install Claude Code", "code": "npm install -g @anthropic-ai/claude-code" },
                    { "caption": "In your terminal, run", "code": "/mcp" },
                    { "caption": "NeoSapien appears as disconnected — select it to connect" },
                    { "caption": "Sign in when prompted (OAuth), then verify the status with", "code": "claude mcp list" },
                    { "caption": "Try your first prompt: “What do you know about me from Neosapien?”" },
                    { "caption": "Congrats! NeoSapien is now connected to Claude Code." }
                  ]
                },
                { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/claude-code.png", "ratio": 1.3333 }
              ]
            }
          ]
        },
        {
          "type": "callout",
          "title": "If NeoSapien MCP doesn't work or appear in the chat, do one of these:",
          "bullets": [
            "Add “from NeoSapien” to your message",
            "Close the tab and reopen Claude",
            "Re-authenticate with the existing NeoSapien account",
            "Remove the NeoSapien from connectors and add it again."
          ]
        },
        { "type": "card", "title": "Troubleshooting", "action": "screen:troubleshooting" },
        { "type": "card", "title": "FAQs", "action": "screen:faq" }
      ]
    },
    "other": {
      "present": "screen",
      "blocks": [
        {
          "type": "header",
          "title": "Connect Neo 1 with other Connector",
          "subtitle": "Give any AI assistant direct access to your NeoSapien memories."
        },
        {
          "type": "callout",
          "tone": "accent",
          "title": "Requires laptop for setup",
          "bullets": ["Works everywhere once connected."]
        },
        {
          "type": "steps",
          "items": [
            { "caption": "Open your tool's MCP settings" },
            { "caption": "Add the server URL", "code": "https://api.neosapien.xyz/mcp" },
            { "caption": "Sign in with the NeoSapien account (this can be different from your ChatGPT account)" },
            { "caption": "Congrats! NeoSapien MCP is now connected" }
          ]
        },
        { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/other.png", "ratio": 1.3333 },
        {
          "type": "callout",
          "title": "If NeoSapien MCP doesn't work or appear in the chat, do one of these:",
          "bullets": [
            "Add “from NeoSapien” to your message",
            "Close the tab and reopen your AI tool",
            "Re-authenticate with the existing NeoSapien account",
            "Remove the NeoSapien from connectors and add it again."
          ]
        },
        { "type": "card", "title": "Troubleshooting", "action": "screen:troubleshooting" },
        { "type": "card", "title": "FAQs", "action": "screen:faq" }
      ]
    },
    "faq": {
      "present": "screen",
      "blocks": [
        { "type": "header", "title": "FAQs" },
        {
          "type": "faq",
          "items": [
            {
              "question": "What is NeoSapien MCP?",
              "answer": "MCP connects your AI assistant to your NeoSapien memories. Your AI can search, retrieve and reference everything you have recorded — without copy-pasting or switching apps."
            },
            {
              "question": "Which AI tools are supported?",
              "answer": "Any AI tool that supports MCP, such as Claude or ChatGPT Pro. Tools without MCP support won't work."
            },
            {
              "question": "Do I need to set it up every time?",
              "answer": "No. It's a one-time setup. Once connected, NeoSapien stays available in your AI tool."
            },
            {
              "question": "Is my data safe?",
              "answer": "Your memories are shared only with the AI tool you connect, over an authenticated (OAuth) sign-in. You can remove NeoSapien from your connectors at any time."
            },
            {
              "question": "What if my AI says it cannot find memories?",
              "answer": "Add “from NeoSapien” to your message. If it still doesn't work, re-authenticate or remove and re-add NeoSapien from your connectors."
            },
            {
              "question": "How do I get my API key?",
              "answer": "MCP uses OAuth sign-in, so there's no API key to paste — just sign in with your NeoSapien account when prompted."
            },
            {
              "question": "Can I use the same account across multiple AI tools?",
              "answer": "Yes. Sign in with the same NeoSapien account in each tool to reach the same memories everywhere."
            }
          ]
        }
      ]
    },
    "troubleshooting": {
      "present": "screen",
      "blocks": [
        { "type": "header", "title": "Troubleshooting" },
        {
          "type": "callout",
          "title": "AI says it has no tools or cannot find MCP",
          "bullets": ["Restart your AI app after adding the NeoSapien MCP. The tool only loads on startup."]
        },
        {
          "type": "callout",
          "title": "Hammer icon not showing in Claude Desktop",
          "bullets": ["Check claude_desktop_config.json for JSON formatting errors. Ensure the file is in the correct directory."]
        },
        {
          "type": "callout",
          "title": "AI finds no memories",
          "bullets": ["Add 'from NeoSapien MCP' to your prompt. Without this trigger the AI may not query your memories. Restart the app if it persists."]
        },
        {
          "type": "callout",
          "title": "MCP server timeout",
          "bullets": ["Check your internet connection. The server at api.neosapien.xyz/mcp must be reachable."]
        },
        {
          "type": "callout",
          "title": "Config changes not taking effect",
          "bullets": ["Fully quit and relaunch the app, not just reload."]
        },
        { "type": "text", "body": "Still having issues?" },
        { "type": "cta", "label": "Contact Support", "action": "https://neosapien.xyz/support", "emphasis": "high" }
      ]
    }
  }
}
''';
