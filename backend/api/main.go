package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/sgo-byan/clipperai/internal/clip"
	"github.com/sgo-byan/clipperai/internal/pkg/ollama"
)

func getEnvOrDefault(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}

func main() {
	// Coba load .env file (abaikan error jika file tidak ada)
	_ = godotenv.Load()

	port := getEnvOrDefault("PORT", "8080")
	ollamaURL := getEnvOrDefault("OLLAMA_URL", "http://localhost:11434")
	ollamaModel := getEnvOrDefault("OLLAMA_MODEL", "llama3.2")
	outputDir := getEnvOrDefault("OUTPUT_DIR", "outputs")

	// Create output dir if it doesn't exist
	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
		log.Fatalf("[MAIN] Failed to create output directory: %v", err)
	}

	store := clip.NewJobStore()
	ollamaClient := ollama.NewClient(ollamaURL, ollamaModel)
	service := clip.NewClipService(store, ollamaClient, outputDir)
	handler := clip.NewClipHandler(store, service)

	r := gin.Default()

	v1 := r.Group("/api/v1")
	{
		v1.POST("/clips", handler.SubmitClip)
		v1.GET("/clips/:id", handler.GetClipStatus)
	}

	log.Printf("[MAIN] Server starting on :%s", port)
	r.Run(":" + port)
}
