"""CPU/API-first defaults that must remain independent of GPU packages."""

import importlib.util
from pathlib import Path
import sys


CONFIG_PATH = Path(__file__).parents[1] / "code/4-agent-customization/bash_agent/config.py"
MODULE4_ROOT = CONFIG_PATH.parents[1]


def load_config_module():
    spec = importlib.util.spec_from_file_location("module4_config", CONFIG_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_module_four_defaults_to_hosted_api_cpu_mode(monkeypatch):
    monkeypatch.delenv("WORKSHOP_INFERENCE_MODE", raising=False)
    monkeypatch.delenv("MODEL_DEVICE", raising=False)
    monkeypatch.delenv("CUSTOM_MODEL_BASE_URL", raising=False)
    monkeypatch.delenv("CUSTOM_MODEL_NAME", raising=False)

    config = load_config_module().Config()

    assert config.use_api is True
    assert config.device == "cpu"
    assert config.api_base_url == "https://integrate.api.nvidia.com/v1"
    assert config.api_model_name == "nvidia/nvidia-nemotron-nano-9b-v2"


def test_module_four_uses_api_client_when_cpu_mode_is_default(monkeypatch):
    monkeypatch.setenv("NVIDIA_API_KEY", "test-key")
    monkeypatch.delenv("WORKSHOP_INFERENCE_MODE", raising=False)
    sys.path.insert(0, str(MODULE4_ROOT))
    try:
        from bash_agent.config import Config
        from bash_agent.helpers import OpenAILLM, get_llm

        assert isinstance(get_llm(Config()), OpenAILLM)
    finally:
        sys.path.remove(str(MODULE4_ROOT))
