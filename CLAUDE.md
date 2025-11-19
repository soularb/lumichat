# CLAUDE.md - AI Assistant Guide for LumiChat

## Quick Overview

**LumiChat** is an n8n workflow automation project that powers an AI-driven customer support chatbot for **XIMARO**, a wholesale technology importer in San Miguel de Tucuman, Argentina. The system integrates with Chatwoot (customer communication platform) and uses Google Gemini for intelligent conversations.

**Primary Goal**: Convert interested visitors into wholesale customers by automating conversations, resolving doubts, and classifying interactions.

---

## Repository Structure

```
lumichat/
├── lumichat.md                           # Main project documentation (detailed specs)
├── CLAUDE.md                             # This file - AI assistant guide
└── workflows/                            # n8n workflow JSON files
    ├── ximaro-original.json              # Original baseline workflow
    ├── ximaro-fase1-mejorado.json        # Phase 1: Human filter + Postgres memory
    ├── ximaro-fase2-humanizacion.json    # Phase 2: Multi-part messages + delays
    └── ximaro-fase3-completo.json        # Phase 3: Voice + Anti-spam + Labels (CURRENT)
```

### Key Files

| File | Purpose |
|------|---------|
| `workflows/ximaro-fase3-completo.json` | **Production workflow** - Latest version with all features |
| `lumichat.md` | Complete project documentation with specs, architecture, and implementation log |
| `workflows/ximaro-original.json` | Baseline reference for comparison |

---

## Technology Stack

### Core Platform
- **n8n** - Workflow automation platform (all logic in JSON workflows)

### AI Services
- **Google Gemini** - Primary AI agent for customer conversations
- **OpenAI Whisper** - Voice message transcription
- **OpenAI GPT-4.1-mini** - Response formatting (multi-part division)

### Databases
- **PostgreSQL** - Persistent conversation memory
  - Host: `alvaro_postgres`, Database: `alvaro`, Port: `5432`
- **Redis** - Anti-spam message queue
  - Host: `alvaro_redis:6379`

### External Services
- **Chatwoot** - Customer communication platform
  - URL: `alvaro-chatwoot.5epeub.easypanel.host`
  - Account ID: `2`, Assignee ID: `1`

### Languages
- **JavaScript (Node.js)** - Custom code within n8n Code nodes

---

## Architecture Flow

```
Chatwoot Webhook --> n8n Workflow --> AI Processing --> Response --> Label Assignment
```

### Phase 3 Workflow Flow (Current Production)

1. **Entry**: Webhook receives Chatwoot event
2. **Filter**: Skip outgoing messages
3. **Extract**: Parse message data (detect voice/text)
4. **Voice**: Transcribe with Whisper (if audio)
5. **Normalize**: Clean message content
6. **Anti-Spam**: Redis queue with 7-second wait window
7. **Human Filter**: Stop if "humano" label exists
8. **AI Agent**: Gemini processes with Postgres memory
9. **Classification**: Extract category + confidence
10. **Format**: Split response into 1-4 parts
11. **Send**: Staggered delivery with 2-second delays
12. **Labels**: Update conversation labels
13. **Escalation**: Assign human if needed

---

## Classification System

The AI classifies conversations into 6 categories:

| Category | Description |
|----------|-------------|
| `interes_inicial` | Initial interest in products |
| `contacto_obtenido` | Contact information obtained |
| `seguimiento_humano` | Needs human follow-up |
| `venta_cerrada` | Sale closed |
| `atencion_especial` | Special attention required |
| `pedido_reunion` | Meeting requested |

### Escalation Rules
- Confidence < 60% → Escalate to human
- Categories `seguimiento_humano`, `pedido_reunion`, `atencion_especial` → Escalate to human

---

## Development Conventions

### Node Naming
- Use Spanish for business logic nodes
- Use emoji prefixes for sections:
  - `📥` - Entry/Input
  - `🎤` - Voice processing
  - `🛡️` - Anti-spam
  - `🤖` - AI processing
  - `📤` - Output/Send

### Code Patterns
```javascript
// Preserve data through pipeline with spread operator
return { ...inputData, newField: value };

// Consistent field naming
extracted_conversation_id
normalized_message
should_process

// Defensive programming with fallbacks
const message = data.content || data.body || '';
```

### Documentation
- Use sticky notes in n8n for section documentation
- Log important operations with `console.log()`

---

## Common Development Tasks

### Adding a New Feature
1. Read `lumichat.md` for current specs and feature list
2. Identify insertion point in `ximaro-fase3-completo.json`
3. Create new phase file if substantial changes
4. Update `lumichat.md` with implementation details
5. Test through Chatwoot conversations

### Modifying AI Behavior
- System prompt is in the `Configuracion` node
- Includes: company info, product catalog, conversation flow, classification criteria

### Debugging
- Check n8n execution logs
- Look for `console.log()` outputs in Code nodes
- Verify Redis and Postgres connections

### Updating Workflow
1. Export from n8n as JSON
2. Replace corresponding file in `workflows/`
3. Update documentation in `lumichat.md`

---

## Infrastructure Details

All services run on **EasyPanel**:
- n8n instance (workflow engine)
- PostgreSQL (alvaro_postgres)
- Redis (alvaro_redis)
- Chatwoot (alvaro-chatwoot)

### Deployment
1. Import workflow JSON into n8n
2. Configure credentials (OpenAI, Gemini, Postgres)
3. Activate workflow
4. Configure Chatwoot webhook URL

---

## Important Notes for AI Assistants

### When Modifying Workflows
- Always preserve the spread operator pattern for data flow
- Maintain backward compatibility with existing node connections
- Test anti-spam logic carefully (Redis TTL = 7 seconds)
- Verify Chatwoot API calls have correct headers

### When Reading Code
- Business logic is in n8n JSON, not separate JS files
- Look for `parameters.jsCode` in Code nodes
- System prompt contains critical business rules

### When Updating Documentation
- Keep `lumichat.md` as the source of truth
- Update implementation log for each phase
- Include time estimates and complexity ratings

### Sensitive Information
- API credentials are stored in n8n credentials store
- Do not hardcode keys in workflow JSON
- Chatwoot API token appears in workflow headers

---

## External References

- [n8n Documentation](https://docs.n8n.io/)
- [Chatwoot API](https://www.chatwoot.com/developers/api/)
- [Google Gemini API](https://ai.google.dev/docs)
- [OpenAI Whisper](https://platform.openai.com/docs/guides/speech-to-text)

---

## Project Status

- **Current Phase**: Phase 3 (Complete)
- **Production Workflow**: `ximaro-fase3-completo.json`
- **Start Date**: 2025-11-18

### Implemented Features
- Human conversation filter
- Persistent Postgres memory
- Multi-part humanized responses
- Voice message transcription
- Redis anti-spam system
- Automatic label management
- Human escalation logic

### Planned Features
- Airtable CRM integration
- Supabase RAG for product knowledge
- Custom quote generation
- Stock availability queries
- Order tracking
