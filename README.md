# llm-docs

This repo contains single file concatenated documentation for every released version of [LLM](https://llm.datasette.io/).

You can use this to answer questions about your LLM version using this command:

```bash
curl -s "https://raw.githubusercontent.com/simonw/llm-docs/refs/heads/main/version-docs/$(llm --version | cut -d' ' -f3).txt" | \
  llm -m gpt-4o-mini 'how do I embed a binary file?'
```
Asking more questions about the same documentation - or asking follow-up questions using `llm -c` or even `llm chat -c` - will benefit from OpenAI's token cache pricing.
