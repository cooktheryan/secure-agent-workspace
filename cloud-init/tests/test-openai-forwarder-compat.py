#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path


repo_root = Path(__file__).resolve().parents[2]
forwarder_path = repo_root / "cloud-init" / "ansible" / "files" / "openai_forwarder.py"
spec = importlib.util.spec_from_file_location("openai_forwarder", forwarder_path)
forwarder = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(forwarder)


payload = {
    "model": "gpt-5.6-sol",
    "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
    "max_tokens": 64,
}

rewritten = json.loads(
    forwarder.rewrite_chat_completions_body(
        "/v1/chat/completions",
        json.dumps(payload).encode("utf-8"),
        "application/json",
    ).decode("utf-8")
)

assert "max_tokens" not in rewritten
assert rewritten["max_completion_tokens"] == 64
assert rewritten["model"] == "gpt-5.6-sol"
assert rewritten["messages"] == payload["messages"]

unchanged = json.loads(
    forwarder.rewrite_chat_completions_body(
        "/v1/chat/completions",
        json.dumps({**payload, "model": "gpt-4.1"}).encode("utf-8"),
        "application/json",
    ).decode("utf-8")
)

assert unchanged["max_tokens"] == 64
assert "max_completion_tokens" not in unchanged

print("OpenAI forwarder rewrites gpt-5 chat completions token limits")
