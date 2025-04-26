import logging
from agents.lifecycle import AgentHooks

class AgentLogger(AgentHooks):
    def __init__(self, logger):
        self.logger = logger

    async def on_start(self, context, agent):
        self.logger.info(f"Agent {agent.name} started with context: {context.context}")

    async def on_end(self, context, agent, output):
        self.logger.info(f"Agent {agent.name} completed with output: {output}")

    async def on_handoff(self, context, agent, source):
        self.logger.info(f"Handoff from {source.name} to {agent.name}")

    async def on_tool_start(self, context, agent, tool):
        self.logger.info(f"Agent {agent.name} starting tool: {tool.name}")

    async def on_tool_end(self, context, agent, tool, result):
        self.logger.info(f"Agent {agent.name} completed tool {tool.name} with result: {result}") 