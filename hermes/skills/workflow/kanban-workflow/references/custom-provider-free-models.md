# Custom Provider for Free Models

## Overview

Use self-hosted gateways (9router, OpenCode Free tier) as custom providers for kanban workers.

## Setup

### 1. Configure Profile

```bash
# Set model to free tier
hermes config set model.default oc/deepseek-v4-flash-free --profile implementer
hermes config set model.provider custom --profile implementer
hermes config set model.base_url "https://router.example.com/v1" --profile implementer

# Add API key
echo 'OPENAI_API_KEY=sk-...' >> ~/.hermes/profiles/implementer/.env
```

### 2. Available Free Models (9router + OpenCode Free)

- `oc/deepseek-v4-flash-free` — Strong coding, free
- `oc/mimo-v2.5-free` — Good general, free
- `oc/nemotron-3.5-lightning-free` — Fast, free
- `oc/hy3-free` — Balanced, free

### 3. Verify Connection

```bash
curl -s "https://router.example.com/v1/chat/completions" \
  -H "Authorization: Bearer sk-..." \
  -H "Content-Type: application/json" \
  -d '{"model":"oc/deepseek-v4-flash-free","messages":[{"role":"user","content":"Say hi"}],"max_tokens":10}'
```

## Trade-offs

| Model | Cost | Coding Quality | Best For |
|-------|------|----------------|----------|
| mimo-v2.5 (Go) | $0.14/$0.28 | Good | Review, general |
| DeepSeek V4 Flash (9router) | Free | Better | Implementation |
| GPT-5.6 Luna (Go) | $0.20/$1.20 | Excellent | Complex tasks |

**Recommendation:** Use free models for high-volume implementation, keep paid models for review.

## Pitfalls

1. Free models may have rate limits or queue times
2. Self-hosted gateways consume VM resources
3. Model quality varies — test before committing to a provider
4. API key security — never commit keys to repos
