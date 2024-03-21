from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix='chaos_')

    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_keepalive: int = 60
    mqtt_username: Optional[str] = None
    mqtt_password: Optional[str] = None
    mqtt_ssl: bool = False

    uvicorn_host: str = "localhost"
    uvicorn_port: int = 5000

    logger_formatter: str = Field('%(asctime)s - %(levelname)s - %(name)s - %(message)s')


