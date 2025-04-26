from openai import OpenAI
from typing import Dict, Optional, Any, List, Union
import os
import logging
from logging import LoggerAdapter
from dotenv import load_dotenv
from ..config.logging_config import setup_logging
from ..agents.agent_definitions import gateway_agent, Runner
from agents.exceptions import InputGuardrailTripwireTriggered
from agents.tracing import trace, custom_span

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
        self.logger.info("OpenAIService initialization completed")

    async def process_query(
            self,
            query: str,
            assistant_id: Optional[str] = None,
            thread_id: Optional[str] = None,
            metadata: Optional[Dict[str, Any]] = None,
            tags: Optional[Union[List[str], Dict[str, str]]] = None
    ) -> Dict:
        """
        Process a query using the gateway agent

        Args:
            query: The user query to process
            assistant_id: Optional assistant ID
            thread_id: Optional thread ID for conversation tracking
            metadata: Optional metadata to include in the trace
            tags: Optional tags for filtering in the OpenAI dashboard. 
                 Can be a list of strings or a dictionary of key-value pairs.
        """
        try:
            self.logger.info(f"Processing query: {query}")

            # Create context with conversation tracking
            context = {
                "conversation_id": thread_id or "new_thread",
                "assistant_id": assistant_id,
                "query": query
            }

            # Prepare trace metadata
            trace_metadata = {
                "user_query": query,
                "conversation_id": thread_id or "new_thread",
                "assistant_id": assistant_id
            }

            # Add any custom metadata provided by the caller
            if metadata:
                trace_metadata.update(metadata)

            # Add tags in a structured format for dashboard filtering
            if tags:
                if isinstance(tags, list):
                    # Convert list of tags to a dictionary with boolean values
                    # This format makes it easier to filter in the dashboard
                    tag_dict = {f"tag_{tag}": True for tag in tags}
                    trace_metadata.update(tag_dict)
                elif isinstance(tags, dict):
                    # Add prefixed tag keys to make them easily identifiable
                    tag_dict = {f"tag_{k}": v for k, v in tags.items()}
                    trace_metadata.update(tag_dict)

            # Create a workflow name that includes primary tag if available
            primary_tag = None
            if isinstance(tags, list) and tags:
                primary_tag = tags[0]
            elif isinstance(tags, dict) and tags:
                primary_tag = next(iter(tags.keys()))

            workflow_name = f"SQL Query Processing{f' - {primary_tag}' if primary_tag else ''}"

            with trace(workflow_name, metadata=trace_metadata) as current_trace:
                self.logger.info(f"Created trace with ID: {current_trace.trace_id}, workflow: {workflow_name}")
                if tags:
                    self.logger.info(f"Applied tags: {tags}")

                # Add callbacks for logging
                context["callbacks"] = {
                    "on_prompt": self._log_prompt,
                    "on_response": self._log_response,
                    "on_agent_start": self._log_agent_start,
                    "on_agent_end": self._log_agent_end,
                    "on_guardrail_check": self._log_guardrail_check,
                    "on_guardrail_result": self._log_guardrail_result
                }

                self.logger.info("Starting Gateway Agent with logging callbacks")

                

                # Create a custom span for the query type with tags
                with custom_span("query_processing",
                                 metadata={"query_type": self._detect_query_type(query), "tags": tags}) as query_span:
                    # Run the gateway agent which will handle guardrail checks internally
                
                    decision = handle_user_query(query)
                        if not decision["allow"]:
                            return {
                                        "response": decision.get("message", "..."),
                                        "status": "denied",
                                        "attack_type": decision["attack_type"]
                                    }
       
                        safe_query = decision.get("forward_query", query)

                    result = await Runner.run(
                        gateway_agent,
                        safe_query,
                        context=context
                    )

                # Log the completion and result
                self.logger.info(f"Gateway Agent completed processing. Result: {result.final_output}")

                # Extract and log the trace information if available
                if hasattr(result, 'trace') and result.trace:
                    self._log_trace(result.trace)

                response = {
                    "response": result.final_output,
                    "status": "completed",
                    "trace": result.trace if hasattr(result, 'trace') else None,
                    "trace_id": current_trace.trace_id,  # Include trace ID in response
                    "workflow_name": workflow_name,  # Include workflow name for reference
                    "tags": tags  # Include applied tags in response
                }

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

    def _detect_query_type(self, query: str) -> str:
        """
        Simple detection of query type for tagging
        """
        query_lower = query.lower()
        if "select" in query_lower:
            return "SELECT"
        elif "insert" in query_lower:
            return "INSERT"
        elif "update" in query_lower:
            return "UPDATE"
        elif "delete" in query_lower:
            return "DELETE"
        elif "create" in query_lower:
            return "CREATE"
        elif "alter" in query_lower:
            return "ALTER"
        elif "drop" in query_lower:
            return "DROP"
        else:
            return "OTHER"

    def _log_prompt(self, agent_name, prompt):
        """Log the prompt being sent to an agent"""
        prompt_logger = LoggerAdapter(base_logger, {"agent_name": agent_name, "message_type": "PROMPT"})
        prompt_logger.info(f"PROMPT to {agent_name}: {prompt}")

    def _log_response(self, agent_name, response):
        """Log the response received from an agent"""
        response_logger = LoggerAdapter(base_logger, {"agent_name": agent_name, "message_type": "RESPONSE"})
        response_logger.info(f"RESPONSE from {agent_name}: {response}")

    def _log_agent_start(self, agent_name, input_data):
        """Log when an agent starts processing"""
        agent_logger = LoggerAdapter(base_logger, {"agent_name": agent_name, "message_type": "AGENT_START"})
        agent_logger.info(f"Agent {agent_name} STARTED with input: {input_data}")

    def _log_agent_end(self, agent_name, output_data):
        """Log when an agent completes processing"""
        agent_logger = LoggerAdapter(base_logger, {"agent_name": agent_name, "message_type": "AGENT_END"})
        agent_logger.info(f"Agent {agent_name} COMPLETED with output: {output_data}")

    def _log_guardrail_check(self, guardrail_name, input_data):
        """Log when a guardrail check is performed"""
        guardrail_logger = LoggerAdapter(base_logger,
                                         {"guardrail_name": guardrail_name, "message_type": "GUARDRAIL_CHECK"})
        guardrail_logger.info(f"Guardrail {guardrail_name} checking input: {input_data}")

    def _log_guardrail_result(self, guardrail_name, result, details=None):
        """Log the result of a guardrail check"""
        guardrail_logger = LoggerAdapter(base_logger,
                                         {"guardrail_name": guardrail_name, "message_type": "GUARDRAIL_RESULT"})
        guardrail_logger.info(f"Guardrail {guardrail_name} result: {result}, details: {details}")

    def _log_trace(self, trace):
        """Log the trace information from the result"""
        trace_logger = LoggerAdapter(base_logger, {"message_type": "TRACE"})
        trace_logger.info("Execution trace:")

        # Log each step in the trace
        if isinstance(trace, list):
            for i, step in enumerate(trace):
                trace_logger.info(f"Step {i + 1}: {step}")
        elif isinstance(trace, dict):
            for key, value in trace.items():
                trace_logger.info(f"{key}: {value}")
        else:
            trace_logger.info(f"Raw trace: {trace}")


# Initialize service
base_logger.info("Creating OpenAIService instance")
openai_service = OpenAIService()
base_logger.info("OpenAIService instance created successfully")
