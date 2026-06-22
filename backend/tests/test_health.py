def test_health_returns_ok(client):
    response = client.get("/api/health")
    assert response.status_code == 200


def test_health_body(client):
    data = client.get("/api/health").json()
    assert data["status"] == "ok"
    assert data["db"] == "ok"
    assert data["version"] == "0.1.0"
