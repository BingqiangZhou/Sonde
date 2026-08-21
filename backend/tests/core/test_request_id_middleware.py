"""Request-id middleware and log-correlation tests."""

import logging

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.middleware import RequestIDFilter, RequestIDMiddleware, request_id_var


def _app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(RequestIDMiddleware)

    @app.get("/ping")
    async def ping():
        return {"request_id": request_id_var.get()}

    return app


def test_generates_request_id_when_absent():
    client = TestClient(_app())
    response = client.get("/ping")

    rid = response.headers.get("X-Request-ID")
    assert rid and len(rid) >= 8
    assert response.json()["request_id"] == rid


def test_echoes_valid_incoming_request_id():
    client = TestClient(_app())
    response = client.get("/ping", headers={"X-Request-ID": "trace-abc12345"})

    assert response.headers["X-Request-ID"] == "trace-abc12345"


def test_replaces_unsafe_incoming_request_id():
    client = TestClient(_app())
    response = client.get("/ping", headers={"X-Request-ID": "bad id\nwith junk"})

    rid = response.headers["X-Request-ID"]
    assert rid != "bad id\nwith junk"
    assert " " not in rid


def test_request_id_filter_injects_record_field():
    request_id_var.set("filter-test-1234")
    try:
        record = logging.LogRecord(
            name="x",
            level=logging.INFO,
            pathname=__file__,
            lineno=1,
            msg="hello",
            args=(),
            exc_info=None,
        )
        assert RequestIDFilter().filter(record) is True
        assert record.request_id == "filter-test-1234"
    finally:
        request_id_var.set("")


def test_request_id_filter_defaults_outside_request():
    request_id_var.set("")
    record = logging.LogRecord(
        name="x",
        level=logging.INFO,
        pathname=__file__,
        lineno=1,
        msg="bg task",
        args=(),
        exc_info=None,
    )
    RequestIDFilter().filter(record)
    assert record.request_id == "-"
