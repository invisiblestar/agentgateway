from agents import Agent, InputGuardrail, GuardrailFunctionOutput, Runner
from pydantic import BaseModel
from ..services.database_service import get_all_users_tool, get_user_by_username_tool, get_user_by_email_tool
from ..config.agent_logger import AgentLogger
import logging
from ..services.gateway_policy import handle_user_query


logger = logging.getLogger(__name__)
agent_logger = AgentLogger(logger)

class DatabaseQueryOutput(BaseModel):
    is_database_query: bool
    reasoning: str

# SQL agent for database queries
sql_agent = Agent(
    name="SQL Agent",
    instructions="""You are a SQL agent that processes user queries about the database.
        You can help users find information about users in the database.
        Use the available tools to answer user queries about the database.
        Format your responses in a clear and readable way.""",
    tools=[get_all_users_tool, get_user_by_username_tool, get_user_by_email_tool],
)
sql_agent.hooks = agent_logger

# Guardrail agent to check if query is database-related
guardrail_agent = Agent(
    name="Database Guardrail",
    instructions="""You are a guardrail agent that checks if queries are related to Postgres databases.
        If the query is about Postgres databases, pass the query to the SQL Agent.
        If the query is not about Postgres databases, return message: 'This query is not about Postgres database.'.
        """,
    output_type=DatabaseQueryOutput,
)
guardrail_agent.hooks = agent_logger

async def database_guardrail(ctx, agent, input_data):
    """
    Guardrail function to check if the query is database-related
    """
    result = await Runner.run(guardrail_agent, input_data, context=ctx.context)
    final_output = result.final_output_as(DatabaseQueryOutput)
    return GuardrailFunctionOutput(
        output_info=final_output,
        tripwire_triggered=not final_output.is_database_query,
    )

# Gateway agent for general queries

def policy_guardrail_fn(user_query: str) -> GuardrailFunctionOutput:

    decision = handle_user_query(user_query)
    if not decision["allow"]:
        return GuardrailFunctionOutput(
            triggered=True,
            instructions=[  # это то, что вернётся клиенту
                decision.get("message", "Query is blocked")
            ]
        )

    return GuardrailFunctionOutput(triggered=False)

gateway_agent = Agent(
    name="Gateway Agent",
    instructions="""You are a gateway agent that processes user queries.
        When receiving 'SQL INJECTION' in the query, return 'Better luck next time!'
        Otherwise, process the query directly.""",
    handoffs=[sql_agent],
    input_guardrails=[
        InputGuardrail(guardrail_function=policy_guardrail_fn),
        InputGuardrail(guardrail_function=database_guardrail),
    ],
)
gateway_agent.hooks = agent_logger
