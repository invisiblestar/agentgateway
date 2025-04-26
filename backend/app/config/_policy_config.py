from pydantic import BaseSettings, Field
from typing import List

class PolicySettings(BaseSettings):
    OPENAI_API_KEY: str = Field(..., env="OPENAI_API_KEY")
    LLM_MODEL: str = Field("gpt-4o-mini", env="LLM_MODEL")
    BANNED_KEYWORDS: List[str] = Field(
        ["delete","drop","update","truncate","modify","shutdown"],
        env="BANNED_KEYWORDS"
    )
    # Если у вас есть JSON с safe-policies, можно указать путь:
    SAFEPOLICIES_PATH: str = Field("config/safe_policies.json", env="SAFEPOLICIES_PATH")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

policy_settings = PolicySettings()