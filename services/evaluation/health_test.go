package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// O healthHandler nao toca em nenhuma dependencia do App (banco, Redis,
// SQS), entao o zero value basta — o teste roda sem infraestrutura.
func TestHealthHandler(t *testing.T) {
	app := &App{}

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	app.healthHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status HTTP: esperado %d, obtido %d", http.StatusOK, rec.Code)
	}

	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("resposta nao e um JSON valido: %v", err)
	}

	if body["status"] != "ok" {
		t.Errorf("campo status: esperado \"ok\", obtido %q", body["status"])
	}
}
