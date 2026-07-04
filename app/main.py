"""FastAPI implementation of the PulseCheck health-monitoring service."""

from __future__ import annotations

import os
import shutil
import socket
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime
from typing import Any

from fastapi import FastAPI
from fastapi.responses import JSONResponse, PlainTextResponse

from app import __version__

START_TIME = time.time()


app = FastAPI(
    title="PulseCheck",
    description="Lightweight health-check microservice for the DevOps assessment.",
    version=__version__,
)


def utc_timestamp() -> str:
    """Return a compact UTC ISO-8601 timestamp."""
    return datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def env_int(name: str, default: int) -> int:
    value = os.getenv(name, "").strip()
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def check_app() -> dict[str, Any]:
    return {
        "status": "ok",
        "version": os.getenv("APP_VERSION", __version__),
        "hostname": socket.gethostname(),
        "uptime_seconds": round(time.time() - START_TIME, 2),
    }


def check_disk() -> dict[str, Any]:
    minimum_free_mb = env_int("DISK_MIN_FREE_MB", 64)
    usage = shutil.disk_usage("/")
    free_mb = usage.free // (1024 * 1024)
    total_mb = usage.total // (1024 * 1024)
    status = "ok" if free_mb >= minimum_free_mb else "failed"

    return {
        "status": status,
        "free_mb": free_mb,
        "total_mb": total_mb,
        "minimum_free_mb": minimum_free_mb,
    }


def read_mem_available_mb() -> int | None:
    """Read available memory on Linux containers when /proc/meminfo exists."""
    try:
        with open("/proc/meminfo", encoding="utf-8") as meminfo:
            for line in meminfo:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except (OSError, ValueError, IndexError):
        return None
    return None


def check_memory() -> dict[str, Any]:
    minimum_available_mb = env_int("MEMORY_MIN_AVAILABLE_MB", 32)
    available_mb = read_mem_available_mb()
    if available_mb is None:
        return {
            "status": "skipped",
            "reason": "memory metric is unavailable on this platform",
            "minimum_available_mb": minimum_available_mb,
        }

    status = "ok" if available_mb >= minimum_available_mb else "failed"
    return {
        "status": status,
        "available_mb": available_mb,
        "minimum_available_mb": minimum_available_mb,
    }


def check_external_dependency() -> dict[str, Any]:
    """Optionally check an external dependency when configured."""
    url = os.getenv("HEALTHCHECK_URL") or os.getenv("EXTERNAL_HEALTH_URL", "")
    url = url.strip()
    timeout_seconds = env_int("EXTERNAL_HEALTH_TIMEOUT_SECONDS", 2)

    if not url:
        return {
            "status": "skipped",
            "reason": "HEALTHCHECK_URL is not set",
        }

    started = time.perf_counter()
    try:
        request = urllib.request.Request(url, method="GET", headers={"User-Agent": "pulsecheck/1.0"})
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            status_code = response.getcode()
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        return {
            "status": "ok" if 200 <= status_code < 400 else "failed",
            "url": url,
            "status_code": status_code,
            "latency_ms": latency_ms,
        }
    except (TimeoutError, urllib.error.URLError, OSError) as exc:
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        return {
            "status": "failed",
            "url": url,
            "latency_ms": latency_ms,
            "error": exc.__class__.__name__,
        }


def build_health_payload() -> tuple[dict[str, Any], int]:
    checks = {
        "app": check_app(),
        "disk": check_disk(),
        "memory": check_memory(),
        "external_dependency": check_external_dependency(),
    }
    failed_checks = [name for name, result in checks.items() if result["status"] == "failed"]
    healthy = not failed_checks

    payload: dict[str, Any] = {
        "service": os.getenv("SERVICE_NAME", "pulsecheck"),
        "status": "healthy" if healthy else "unhealthy",
        "timestamp": utc_timestamp(),
        "checks": checks,
    }
    if failed_checks:
        payload["failed_checks"] = failed_checks

    return payload, 200 if healthy else 503


@app.get("/")
def root() -> dict[str, Any]:
    return {
        "service": os.getenv("SERVICE_NAME", "pulsecheck"),
        "message": "PulseCheck is running",
        "endpoints": ["/health", "/ready", "/live"],
        "timestamp": utc_timestamp(),
    }


@app.get("/health")
def health() -> JSONResponse:
    payload, status_code = build_health_payload()
    return JSONResponse(content=payload, status_code=status_code)


@app.get("/ready")
def ready() -> JSONResponse:
    payload, status_code = build_health_payload()
    return JSONResponse(content=payload, status_code=status_code)


@app.get("/live")
def live() -> dict[str, Any]:
    return {
        "service": os.getenv("SERVICE_NAME", "pulsecheck"),
        "status": "alive",
        "timestamp": utc_timestamp(),
        "uptime_seconds": round(time.time() - START_TIME, 2),
    }


@app.get("/metrics", response_class=PlainTextResponse)
def metrics() -> str:
    payload, status_code = build_health_payload()
    is_healthy = 1 if status_code == 200 else 0
    uptime_seconds = payload["checks"]["app"]["uptime_seconds"]
    return "\n".join(
        [
            "# HELP pulsecheck_up 1 when PulseCheck is healthy",
            "# TYPE pulsecheck_up gauge",
            f"pulsecheck_up {is_healthy}",
            "# HELP pulsecheck_uptime_seconds Process uptime in seconds",
            "# TYPE pulsecheck_uptime_seconds counter",
            f"pulsecheck_uptime_seconds {uptime_seconds}",
            "",
        ]
    )
