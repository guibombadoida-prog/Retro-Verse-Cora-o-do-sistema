#!/usr/bin/env python3
"""Envia um pacote RBXM de scripts para uma tarefa Luau Execution.

As tarefas podem apenas comparar/publicar ``Source`` existente ou preparar uma
place privada de código. Este cliente usa somente a biblioteca padrão e nunca
imprime a chave ou a URI assinada de upload.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


API_ROOT = "https://apis.roblox.com/cloud/v2"
MAX_PAYLOAD_BYTES = 20_000_000
MAX_TASK_BYTES = 200_000
TERMINAL_FAILURE_STATES = {"FAILED", "CANCELLED"}
ALLOWED_MODES = {"check", "publish", "bootstrap-check", "bootstrap"}


class PublishError(RuntimeError):
    pass


def required_environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise PublishError(f"variável obrigatória ausente: {name}")
    return value


def validate_numeric_id(name: str, value: str) -> str:
    if not value.isascii() or not value.isdigit() or int(value) <= 0:
        raise PublishError(f"{name} precisa ser um número inteiro positivo")
    return value


def read_payload(path: Path) -> bytes:
    try:
        payload = path.read_bytes()
    except OSError as exc:
        raise PublishError(f"não foi possível ler o pacote {path}: {exc}") from exc
    if not payload:
        raise PublishError(f"o pacote {path} está vazio")
    if len(payload) > MAX_PAYLOAD_BYTES:
        raise PublishError(
            f"o pacote tem {len(payload)} bytes; o limite de segurança é {MAX_PAYLOAD_BYTES}"
        )
    return payload


def build_task_source(
    path: Path,
    mode: str,
    universe_id: str,
    place_id: str,
    *,
    forbidden_universe_id: str = "",
    forbidden_place_id: str = "",
) -> str:
    if mode not in ALLOWED_MODES:
        raise PublishError(f"modo inválido: {mode}")
    try:
        body = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise PublishError(f"não foi possível ler a tarefa {path}: {exc}") from exc

    # Os valores aceitos são restritos, e json.dumps produz literais de string
    # também válidos em Luau. Eles viram locais no mesmo chunk da tarefa.
    header = "\n".join(
        (
            f"local RETROVERSE_MODE = {json.dumps(mode)}",
            f"local EXPECTED_UNIVERSE_ID = {json.dumps(universe_id)}",
            f"local EXPECTED_PLACE_ID = {json.dumps(place_id)}",
            "local FORBIDDEN_PRODUCTION_UNIVERSE_ID = "
            f"{json.dumps(forbidden_universe_id)}",
            f"local FORBIDDEN_PRODUCTION_PLACE_ID = {json.dumps(forbidden_place_id)}",
            "",
        )
    )
    # Mantém uma diretiva --!strict/--!nocheck como primeira linha do chunk.
    if body.startswith("--!"):
        directive, separator, remainder = body.partition("\n")
        source = directive + separator + header + remainder
    else:
        source = header + body
    encoded_size = len(source.encode("utf-8"))
    if encoded_size > MAX_TASK_BYTES:
        raise PublishError(
            f"a tarefa gera {encoded_size} bytes; o limite de segurança é {MAX_TASK_BYTES}"
        )
    return source


class OpenCloudClient:
    def __init__(self, api_key: str) -> None:
        self.api_key = api_key

    def _redact(self, message: str) -> str:
        return message.replace(self.api_key, "[CHAVE_OCULTA]")

    def request_json(
        self,
        method: str,
        url: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        body = None
        headers = {
            "Accept": "application/json",
            "User-Agent": "RetroVerse-GitHub-Actions/2.0",
            "x-api-key": self.api_key,
        }
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"

        for attempt in range(5):
            request = Request(url, data=body, headers=headers, method=method)
            try:
                with urlopen(request, timeout=45) as response:
                    raw = response.read()
                    if not raw:
                        return {}
                    decoded = json.loads(raw.decode("utf-8"))
                    if not isinstance(decoded, dict):
                        raise PublishError("Open Cloud devolveu JSON em formato inesperado")
                    return decoded
            except HTTPError as exc:
                response_body = self._redact(exc.read().decode("utf-8", errors="replace"))
                # POST pode ter sido aceito mesmo se a resposta se perdeu. Não o
                # repetimos para evitar criar duas tarefas de publicação.
                retryable = method == "GET" and (exc.code == 429 or 500 <= exc.code < 600)
                if retryable and attempt < 4:
                    time.sleep(2**attempt)
                    continue
                raise PublishError(f"Open Cloud respondeu HTTP {exc.code}: {response_body}") from exc
            except (URLError, TimeoutError) as exc:
                if method == "GET" and attempt < 4:
                    time.sleep(2**attempt)
                    continue
                reason = self._redact(str(getattr(exc, "reason", exc)))
                raise PublishError(f"falha de rede ao chamar Open Cloud: {reason}") from exc
            except (UnicodeError, json.JSONDecodeError) as exc:
                raise PublishError("Open Cloud devolveu uma resposta JSON inválida") from exc

        raise PublishError("Open Cloud não respondeu após várias tentativas")

    def upload_binary(self, upload_uri: str, payload: bytes) -> None:
        if not upload_uri.startswith("https://"):
            raise PublishError("Open Cloud devolveu uma URI de upload inválida")

        for attempt in range(5):
            request = Request(
                upload_uri,
                data=payload,
                headers={"Content-Type": "application/octet-stream"},
                method="PUT",
            )
            try:
                with urlopen(request, timeout=90) as response:
                    response.read()
                    return
            except HTTPError as exc:
                # Não inclua a URI assinada nem cabeçalhos no erro.
                response_body = exc.read().decode("utf-8", errors="replace")
                if (exc.code == 429 or 500 <= exc.code < 600) and attempt < 4:
                    time.sleep(2**attempt)
                    continue
                raise PublishError(
                    f"o upload binário respondeu HTTP {exc.code}: {response_body}"
                ) from exc
            except (URLError, TimeoutError) as exc:
                if attempt < 4:
                    time.sleep(2**attempt)
                    continue
                reason = str(getattr(exc, "reason", exc))
                raise PublishError(f"falha de rede durante o upload binário: {reason}") from exc

        raise PublishError("o upload binário não respondeu após várias tentativas")


def require_string(response: dict[str, Any], field: str, context: str) -> str:
    value = response.get(field)
    if not isinstance(value, str) or not value:
        raise PublishError(f"{context} não devolveu o campo {field}")
    return value


def print_task_logs(client: OpenCloudClient, task_path: str) -> None:
    response = client.request_json("GET", f"{API_ROOT}/{task_path}/logs")
    groups = response.get("luauExecutionSessionTaskLogs", [])
    if not isinstance(groups, list):
        raise PublishError("resposta de logs em formato inesperado")

    messages: list[str] = []
    for group in groups:
        if not isinstance(group, dict):
            continue
        group_messages = group.get("messages", [])
        if isinstance(group_messages, list):
            messages.extend(str(message) for message in group_messages)

    print("Logs da tarefa Roblox:")
    if messages:
        for message in messages:
            print(f"  {message}")
    else:
        print("  (nenhuma mensagem)")


def poll_task(
    client: OpenCloudClient,
    initial_task: dict[str, Any],
    timeout_seconds: int,
) -> dict[str, Any]:
    task_path = require_string(initial_task, "path", "a criação da tarefa")
    if "://" in task_path or ".." in task_path:
        raise PublishError("Open Cloud devolveu um caminho de tarefa inválido")

    deadline = time.monotonic() + timeout_seconds
    current = initial_task
    state = current.get("state")
    if not isinstance(state, str) or not state:
        raise PublishError("a tarefa não devolveu um estado")
    while state == "PROCESSING":
        if time.monotonic() >= deadline:
            raise PublishError(f"tempo esgotado esperando a tarefa {task_path}")
        time.sleep(2)
        current = client.request_json("GET", f"{API_ROOT}/{task_path.lstrip('/')}")
        state = current.get("state")
        if not isinstance(state, str) or not state:
            raise PublishError("a consulta da tarefa não devolveu um estado")
    return current


def run(args: argparse.Namespace) -> int:
    api_key = required_environment("ROBLOX_API_KEY")
    universe_id = validate_numeric_id(
        "ROBLOX_UNIVERSE_ID", required_environment("ROBLOX_UNIVERSE_ID")
    )
    place_id = validate_numeric_id("ROBLOX_PLACE_ID", required_environment("ROBLOX_PLACE_ID"))
    forbidden_universe_id = os.environ.get("ROBLOX_FORBIDDEN_UNIVERSE_ID", "").strip()
    forbidden_place_id = os.environ.get("ROBLOX_FORBIDDEN_PLACE_ID", "").strip()

    if forbidden_universe_id:
        forbidden_universe_id = validate_numeric_id(
            "ROBLOX_FORBIDDEN_UNIVERSE_ID", forbidden_universe_id
        )
    if forbidden_place_id:
        forbidden_place_id = validate_numeric_id(
            "ROBLOX_FORBIDDEN_PLACE_ID", forbidden_place_id
        )
    if args.mode.startswith("bootstrap"):
        if not forbidden_universe_id or not forbidden_place_id:
            raise PublishError(
                "bootstrap exige ROBLOX_FORBIDDEN_UNIVERSE_ID e "
                "ROBLOX_FORBIDDEN_PLACE_ID"
            )
        if universe_id == forbidden_universe_id:
            raise PublishError("bootstrap recusado na experiência de produção")
        if place_id == forbidden_place_id:
            raise PublishError("bootstrap recusado no place de produção")

    payload = read_payload(args.payload)
    task_source = build_task_source(
        args.task,
        args.mode,
        universe_id,
        place_id,
        forbidden_universe_id=forbidden_universe_id,
        forbidden_place_id=forbidden_place_id,
    )
    client = OpenCloudClient(api_key)

    print(f"Modo: {args.mode}; pacote: {len(payload)} bytes")
    print("1/4 Reservando entrada binária...")
    binary_input = client.request_json(
        "POST",
        f"{API_ROOT}/universes/{universe_id}/luau-execution-session-task-binary-inputs",
        {"size": len(payload)},
    )
    binary_path = require_string(binary_input, "path", "a entrada binária")
    upload_uri = require_string(binary_input, "uploadUri", "a entrada binária")

    print("2/4 Enviando pacote de scripts...")
    client.upload_binary(upload_uri, payload)

    print("3/4 Criando tarefa na versão atual do place...")
    task = client.request_json(
        "POST",
        f"{API_ROOT}/universes/{universe_id}/places/{place_id}/luau-execution-session-tasks",
        {
            "script": task_source,
            "binaryInput": binary_path,
            "enableBinaryOutput": False,
            "timeout": "300s",
        },
    )
    task_path = require_string(task, "path", "a criação da tarefa")

    print("4/4 Aguardando conclusão...")
    completed = poll_task(client, task, args.timeout)
    try:
        print_task_logs(client, task_path.lstrip("/"))
    except PublishError as log_error:
        print(f"AVISO: não foi possível baixar os logs: {log_error}", file=sys.stderr)

    state = str(completed.get("state", "DESCONHECIDO"))
    if state in TERMINAL_FAILURE_STATES or completed.get("error"):
        error = completed.get("error", {})
        if isinstance(error, dict):
            code = error.get("code", state)
            message = error.get("message", "sem detalhes")
        else:
            code, message = state, str(error)
        raise PublishError(f"tarefa Roblox terminou em {state}: {code} - {message}")

    output = completed.get("output", {})
    results = output.get("results", []) if isinstance(output, dict) else []
    print(f"Tarefa concluída com estado {state}")
    if isinstance(results, list) and results:
        print("Retorno:", json.dumps(results, ensure_ascii=False))
    return 0


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Executa uma tarefa de código usando Open Cloud Luau Execution"
    )
    parser.add_argument("--mode", choices=tuple(sorted(ALLOWED_MODES)), default="check")
    parser.add_argument("--payload", type=Path, required=True)
    parser.add_argument("--task", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=330)
    args = parser.parse_args()
    if not 30 <= args.timeout <= 600:
        parser.error("--timeout precisa ficar entre 30 e 600 segundos")
    return args


if __name__ == "__main__":
    try:
        raise SystemExit(run(parse_arguments()))
    except PublishError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
