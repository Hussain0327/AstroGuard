def test_root_endpoint(client):
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "Echo"
    assert data["version"] == "0.1.0"
    assert data["llm"] == "DeepSeek 3.2 Exp"


def test_health_endpoint(client):
    """Test basic health endpoint"""
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "echo-api"
