from openai import OpenAI
from typing import Dict, Optional
import os
import logging
from logging import LoggerAdapter
from dotenv import load_dotenv
from ..config.logging_config import setup_logging
from ..agents.agent_definitions import gateway_agent, Runner
from agents.exceptions import InputGuardrailTripwireTriggered
from ..config.agent_logger import AgentLogger

# Load environment variables
load_dotenv()

# Setup logging
setup_logging()
base_logger = logging.getLogger(__name__)

class OpenAIService:
    def __init__(self):
        self.logger = LoggerAdapter(base_logger, {"agent_name": "OpenAIService"})
        self.logger.info("Initializing OpenAIService")
        self.client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        self.default_assistant_id = os.getenv("OPENAI_DEFAULT_ASSISTANT_ID")
        
        # Add hooks to agents
        self.agent_logger = AgentLogger(self.logger)
        gateway_agent.hooks = self.agent_logger
        self.logger.info("OpenAIService initialization completed")

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
                "query": query,
            }
            
            self.logger.info(f"Starting Runner execution with context: {context}")
            
            # Run the gateway agent which will handle guardrail checks internally
            result = await Runner.run(
                gateway_agent,
                query,
                context=context
            )

            self.logger.info(f"Runner execution completed. Final output: {result.final_output}")
            if hasattr(result, 'trace'):
                self.logger.debug(f"Runner trace: {result.trace}")
            
            response = {
                "response": result.final_output,
                "status": "completed",
                "trace": result.trace if hasattr(result, 'trace') else None
            }
            
            self.logger.info(f"Prepared response with status: {response['status']}")
            return response
            
        except InputGuardrailTripwireTriggered as e:
            # Handle the case when the guardrail is triggered
            self.logger.info(f"Guardrail triggered: {str(e)}")
            return {
                "response": "This query is not about Postgres database.",
                "status": "completed",
                "trace": None
            }
        except Exception as e:
            error_msg = f"Error processing query: {str(e)}"
            self.logger.error(error_msg, exc_info=True)
            raise Exception(error_msg)

# Initialize service
base_logger.info("Creating OpenAIService instance")
openai_service = OpenAIService()
base_logger.info("OpenAIService instance created successfully") 