# Agent Gateway

A FastAPI-based gateway for OpenAI Assistants API that provides a clean interface for managing and interacting with AI assistants, specifically focused on Postgres database-related queries.

## Concept

Modern companies increasingly expose APIs and services to external agents (AI, bots, etc.), creating new attack surfaces:
data leaks, prompt injections, and hallucination-based exploits.

Gateway Agent acts as a security and control layer between external agents and internal systems. 
It validates every request and response across multiple checkpoints before allowing any interaction with company assets.

![Diagram](design/Lavel_0_Gateway_Concept.png)

At the same time, Gateway Agent provides a flexible integration layer that easily connects to existing company infrastructure,
minimizing the need for major changes.

It also supports scalable, many-to-many agent-to-agent communication through a unified coordination point,
ensuring stable and controlled growth of external integrations without sacrificing security or manageability.

### Key Components

The Gateway Agent is designed to be added on top of an existing company API Gateway infrastructure.
Instead of replacing the current setup, it extends the traditional API Gateway model
by introducing an intelligent control layer that enables secure, scalable agent-to-agent interactions.
This allows companies to evolve from simple request-response APIs to dynamic,
multi-agent communication architectures while maintaining full control and visibility. 

We recommend complementing the Gateway Agent with AI Guardrails to introduce an additional mid-layer of security,
capable of detecting and blocking sensitive data access, prompt injections,
and hallucination attempts before they reach critical internal systems.

### How it Works

External agents send requests that first pass through the existing API Gateway for initial routing.
The Gateway Agent then verifies the content and context of each interaction,
blocking unsafe requests and managing secure agent-to-agent communications.
Internal responses are also checked for anomalies before being shared externally.

The system architecture is designed for easy horizontal scalability:
multiple Gateway Agent instances can be deployed to handle high volumes of agent-to-agent
interactions while maintaining stable latency and high availability.
This enables the platform to support a growing number of agents and conversations without performance degradation.

We recommend monitoring key system metrics such as:
- Request validation time (ms)
- Anomaly detection rate (%)
- Average agent-to-agent response latency (ms)
- System throughput (requests per second)
- Error rates (blocked vs allowed requests)


## Features

- Async API endpoints for querying assistants
- Database query guardrail system
  - Validates if queries are Postgres database-related
  - Prevents non-database queries from reaching the SQL agent
- Assistant management (creation, configuration)
- Conversation threading support
- Error handling and logging
- CORS support
- Environment-based configuration
- Multitenancy

## Project Structure

```
agentgateway/
├── backend/
│   ├── app/
│   │   ├── main.py           # FastAPI application
│   │   ├── api/              # API endpoints
│   │   ├── agents/           # AI agent implementations
│   │   ├── config/           # Configuration files
│   │   ├── models/           # Data models
│   │   └── services/         # Business logic services
│   ├── logs/                 # Log files
│   ├── requirements.txt      # Python dependencies
│   ├── pyproject.toml        # Python project configuration
│   └── Makefile             # Backend build commands
├── frontend/
│   ├── src/                  # Next.js source code
│   ├── package.json          # Node.js dependencies
│   ├── tsconfig.json         # TypeScript configuration
│   └── tailwind.config.ts    # Tailwind CSS configuration
├── design/                   # Design documents and diagrams
├── nginx.conf               # Nginx configuration
├── Makefile                 # Main project build commands
└── README.md
```

## Setup

### Using Makefile

The project includes a comprehensive Makefile that simplifies common development tasks. Here are the main commands:

1. Install all dependencies and setup the project:
   ```bash
   make all
   ```

2. Nginx management (Linux only):
   ```bash
   make nginx action=all

   ```

3. Env:
   ```bash
   # Create .env file from example
   make setup-env
   ```

### Running the Application

1. Backend 

   ```bash
   cd backend
   python -B -m uvicorn app.main:app --reload
   ```

1. Frontend 

   ```bash
   cd frontend
   npm run dev
   ```

3. Access the application:
   - Frontend: http://localhost:3000

## API Endpoints

### Query Assistant
```http
POST /api/query
Content-Type: application/json

{
    "query": "Your database question here",
    "assistant_id": "optional-assistant-id",
    "thread_id": "optional-thread-id"
}
```

### Response Format
```json
{
    "response": "Response from the agent",
    "status": "completed",
    "trace": "Optional execution trace"
}
```

## Environment Variables

- `OPENAI_API_KEY`: Your OpenAI API key
