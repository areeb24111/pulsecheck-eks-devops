from __future__ import annotations

import re

from fastapi.testclient import TestClient

import app.main as pulsecheck

client = TestClient(pulsecheck.app)


def test_health_returns_healthy_payload(monkeypatch):
    monkeypatch.delenv("HEALTHCHECK_URL", raising=False)
    monkeypatch.delenv("EXTERNAL_HEALTH_URL", raising=False)

    response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["service"] == "pulsecheck"
    assert body["status"] == "healthy"
    assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", body["timestamp"])
    assert body["checks"]["app"]["status"] == "ok"
    assert body["checks"]["disk"]["status"] == "ok"
    assert body["checks"]["external_dependency"]["status"] == "skipped"


def test_ready_uses_same_health_contract(monkeypatch):
    monkeypatch.delenv("HEALTHCHECK_URL", raising=False)

    response = client.get("/ready")

    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_failed_dependency_returns_503(monkeypatch):
    monkeypatch.setattr(
        pulsecheck,
        "check_external_dependency",
        lambda: {"status": "failed", "url": "https://example.invalid", "error": "URLError"},
    )

    response = client.get("/health")

    assert response.status_code == 503
    body = response.json()
    assert body["status"] == "unhealthy"
    assert body["failed_checks"] == ["external_dependency"]


def test_liveness_endpoint_is_independent_of_dependency_failure(monkeypatch):
    monkeypatch.setattr(
        pulsecheck,
        "check_external_dependency",
        lambda: {"status": "failed", "url": "https://example.invalid", "error": "URLError"},
    )

    response = client.get("/live")

    assert response.status_code == 200
    assert response.json()["status"] == "alive"


def test_root_lists_expected_endpoints():
    response = client.get("/")

    assert response.status_code == 200
    assert set(response.json()["endpoints"]) >= {"/health", "/ready", "/live"}
