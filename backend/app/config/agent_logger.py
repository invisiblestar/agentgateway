import logging
from agents.lifecycle import AgentHooks
from .websocket_manager import websocket_manager

class AgentLogger(AgentHooks):
    def __init__(self, logger):
        self.logger = logger

    async def on_start(self, context, agent):
        log_message = f"Agent {agent.name} started with context: {context.context}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(log_message)

    async def on_end(self, context, agent, output):
        log_message = f"Agent {agent.name} completed with output: {output}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(log_message)

    async def on_handoff(self, context, agent, source):
        log_message = f"Handoff from {source.name} to {agent.name}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(log_message)

    async def on_tool_start(self, context, agent, tool):
        log_message = f"Agent {agent.name} starting tool: {tool.name}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(log_message)

    async def on_tool_end(self, context, agent, tool, result):
        log_message = f"Agent {agent.name} completed tool {tool.name} with result: {result}"
        self.logger.info(log_message)
        await websocket_manager.broadcast(log_message) 