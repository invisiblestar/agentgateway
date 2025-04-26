import logging
from agents.lifecycle import AgentHooks
from .websocket_manager import websocket_manager
import json

class AgentLogger(AgentHooks):
    def __init__(self, logger):
        self.logger = logger

    def _format_log_message(self, log_message):
        # Pretty print dicts or pydantic models, handle newlines in strings
        if hasattr(log_message, 'dict'):
            return json.dumps(log_message.dict(), indent=2, ensure_ascii=False)
        elif isinstance(log_message, dict):
            return json.dumps(log_message, indent=2, ensure_ascii=False)
        elif isinstance(log_message, str):
            return log_message.replace('\\n', '\n')
        else:
            return str(log_message)

    async def on_start(self, context, agent):
        log_message = f"Agent {agent.name} started with context: {context.context}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(self._format_log_message(log_message))

    async def on_end(self, context, agent, output):
        output_str = getattr(output, 'output', None)
        reasoning_str = getattr(output, 'reasoning', None)
        if output_str is not None and reasoning_str is not None:
            log_message = (
                f"Agent {agent.name} completed.\n"
                f"Output: {output_str}\n"
                f"Reasoning: {reasoning_str}"
            )
        else:
            log_message = f"Agent {agent.name} completed with output: {output}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(self._format_log_message(log_message))

    async def on_handoff(self, context, agent, source):
        log_message = f"Handoff from {source.name} to {agent.name}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(self._format_log_message(log_message))

    async def on_tool_start(self, context, agent, tool):
        log_message = f"Agent {agent.name} starting tool: {tool.name}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(self._format_log_message(log_message))

    async def on_tool_end(self, context, agent, tool, result):
        log_message = f"Agent {agent.name} completed tool {tool.name} with result: {result}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(self._format_log_message(log_message)) 