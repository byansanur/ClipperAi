package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/sgo-byan/clipperai/internal/clip"
	"github.com/sgo-byan/clipperai/internal/pkg/ollama"
)

func getRequiredEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("[MAIN] Environment variable %s is required but not set in .env", key)
	}
	return value
}

func main() {
	// Wajib me-load .env file
	if err := godotenv.Load(); err != nil {
		log.Fatalf("[MAIN] Error loading .env file: %v", err)
	}

	port := getRequiredEnv("PORT")
	ollamaURL := getRequiredEnv("OLLAMA_URL")
	ollamaModel := getRequiredEnv("OLLAMA_MODEL")
	outputDir := getRequiredEnv("OUTPUT_DIR")

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
