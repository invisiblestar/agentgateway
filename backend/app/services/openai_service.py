from openai import OpenAI
from typing import Dict, Optional
import os
import logging
from logging import LoggerAdapter
from dotenv import load_dotenv
from agents import Agent, Runner, GuardrailFunctionOutput
from pydantic import BaseModel
from ..config.logging_config import setup_logging

# Load environment variables
load_dotenv()

# Setup logging
setup_logging()
base_logger = logging.getLogger(__name__)

class DatabaseQueryOutput(BaseModel):
    is_database_query: bool
    reasoning: str

class OpenAIService:
    def __init__(self):
        self.logger = LoggerAdapter(base_logger, {"agent_name": "OpenAIService"})
        self.logger.info("Initializing OpenAIService")
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.default_assistant_id = os.getenv("OPENAI_DEFAULT_ASSISTANT_ID")
        
        self.logger.info("Initializing SQL agent")
        # Initialize the SQL agent
        self.sql_agent = Agent(
            name="SQL Agent",
            instructions="""You are a SQL agent that processes user queries.
                When receiving 'SQL INJECTION' in the query, return 'Better luck next time!'
                For now return message: 'SQL Query result.'""",
        )

        # Initialize the database guardrail agent
        self.guardrail_agent = Agent(
            name="Database Guardrail",
            instructions="""You are a guardrail agent that checks if queries are related to Postgres databases.
                If the query is about Postgres databases, pass the query to the SQL Agent.
                If the query is not about Postgres databases, return message: 'This query is not about Postgres database.'.
                """,
            output_type=DatabaseQueryOutput,
        )

        self.logger.info("Initializing gateway agent")
        # Initialize the gateway agent with guardrail
        self.gateway_agent = Agent(
            name="Gateway Agent",
            instructions="""You are a gateway agent that processes user queries.
                If query contains 'SQL INJECTION', hand off to SQL Agent.
                Otherwise, process the query directly.""",
            handoffs=[self.sql_agent]
        )
        self.logger.info("OpenAIService initialization completed")

    async def database_guardrail(self, ctx, agent, input_data):
        """
        Guardrail function to check if the query is database-related
        """
        result = await Runner.run(self.guardrail_agent, input_data, context=ctx.context)
        final_output = result.final_output_as(DatabaseQueryOutput)
        
        if not final_output.is_database_query:
            return GuardrailFunctionOutput(
                output_info=final_output,
                tripwire_triggered=True,
                error_message=f"This query is not about databases. {final_output.reasoning}"
            )
        
        return GuardrailFunctionOutput(
            output_info=final_output,
            tripwire_triggered=False
        )

    async def process_query(
        self,
        query: str,
        assistant_id: Optional[str] = None,
        thread_id: Optional[str] = None
    ) -> Dict:
        """
        Process a query using the gateway agent
        """
        try:
            self.logger.info(f"Processing query: {query}")
            
            # Create context with conversation tracking
            context = {
                "conversation_id": thread_id or "new_thread",
                "assistant_id": assistant_id,
                "query": query
            }
            
            # First check if query is database-related using guardrail agent
            guardrail_result = await Runner.run(
                self.guardrail_agent,
                query,
                context=context
            )
            final_output = guardrail_result.final_output_as(DatabaseQueryOutput)
            
            if not final_output.is_database_query:
                return {
                    "response": "This query is not about Postgres database.",
                    "status": "completed",
                    "trace": None
                }
            
            # If database-related, run the gateway agent
            result = await Runner.run(
                self.gateway_agent,
                query,
                context=context
            )
            
            # Log the completion and result
            self.logger.info(f"Gateway Agent completed processing. Result: {result.final_output}")
            
            response = {
                "response": result.final_output,
                "status": "completed",
                "trace": result.trace if hasattr(result, 'trace') else None
            }
            
            return response
            
        except Exception as e:
            error_msg = f"Error processing query: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            raise Exception(error_msg)

# Initialize service
base_logger.info("Creating OpenAIService instance")
openai_service = OpenAIService()
base_logger.info("OpenAIService instance created successfully") 