package main



import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"context"

	"github.com/joho/godotenv"
	_ "github.com/jackc/pgx/v4/stdlib"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// App struct = injeção de dependência
type App struct {
	DB         *sql.DB
	MasterKey  string
}

func main() {
	_ = godotenv.Load()

   	// --- openTelemetry ---
   	otelCtx := context.Background()
   	shutdownOTel, err := setupOTel(otelCtx)
   	if err != nil {
   		log.Fatalf("Não foi possível iniciar o OpenTelemetry: %v", err)
   	}
   	defer shutdownOTel(otelCtx)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8001" // Porta padrão
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL deve ser definida")
	}

	masterKey := os.Getenv("MASTER_KEY")
	if masterKey == "" {
		log.Fatal("MASTER_KEY deve ser definida")
	}

	db, err := connectDB(databaseURL)
	if err != nil {
		log.Fatalf("Não foi possível conectar ao banco de dados: %v", err)
	}
	defer db.Close()

	app := &App{
		DB:         db,
		MasterKey:  masterKey,
	}

	// --- Rotas da API ---
	mux := http.NewServeMux()
	mux.HandleFunc("/health", app.healthHandler)

	// Endpoint público para validar uma chave
	mux.HandleFunc("/validate", app.validateKeyHandler)

	// Endpoints de "admin" para criar/gerenciar chaves
	mux.Handle("/admin/keys", app.masterKeyAuthMiddleware(http.HandlerFunc(app.createKeyHandler)))

   	log.Printf("Serviço de Autenticação (Go) rodando na porta %s", port)
   	if err := http.ListenAndServe(":"+port, otelhttp.NewHandler(mux, "auth-service")); err != nil {
   		log.Fatal(err)
   	}
}

// connectDB inicializa e testa a conexão com PostgreSQL
func connectDB(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return nil, err
	}

	if err = db.Ping(); err != nil {
		return nil, err
	}

	log.Println("Conectado ao PostgreSQL com sucesso!")
	return db, nil
}