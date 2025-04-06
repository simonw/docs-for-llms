# docs-for-llms

This repo contains single file concatenated documentation for every released version of [LLM](https://llm.datasette.io/) and several other tools.

You can use this to answer questions about your LLM version using this command:

```bash
curl -s "https://raw.githubusercontent.com/simonw/docs-for-llms/refs/heads/main/llm/$(llm --version | cut -d' ' -f3).txt" | \
  llm -m gpt-4o-mini 'how do I embed a binary file?'
```
Asking more questions about the same documentation - or asking follow-up questions using `llm -c` or even `llm chat -c` - will benefit from OpenAI's token cache pricing.

Some of these files are a little large though:

```bash
curl -s 'https://raw.githubusercontent.com/simonw/docs-for-llms/refs/heads/main/datasette/1.0a16.txt' \
  | ttok
```
> 152131

That's 152,000 tokens - too large for `gpt-4o-mini` and quite expensive to process. Approach with caution!
