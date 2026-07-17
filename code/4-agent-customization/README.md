# Module 4: Agent Customization

The default workshop path uses hosted NVIDIA inference and works on a CPU-only
machine. Synthetic-data generation and the API-backed Bash agent are available
from the root environment after `uv sync --locked`.

Local GRPO training and running its resulting checkpoint require an NVIDIA GPU.
On a GPU machine, install that isolated track from the repository root:

```bash
bash scripts/setup-gpu-training.sh
```

Then start the reward server and run `02_grpo_training.ipynb`. A normal NVIDIA
inference API key can use the base hosted model, but it cannot create or host a
locally trained checkpoint. To compare a customized model from a CPU machine,
set `CUSTOM_MODEL_BASE_URL`, `CUSTOM_MODEL_API_KEY`, and `CUSTOM_MODEL_NAME` to
an endpoint that serves that checkpoint.
