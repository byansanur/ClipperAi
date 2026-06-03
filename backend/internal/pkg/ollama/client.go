package ollama

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// Client mengatur koneksi HTTP ke Ollama lokal.
type Client struct {
	baseURL    string
	model      string
	httpClient *http.Client
}

// GenerateRequest mendefinisikan payload untuk memanggil Ollama API.
type GenerateRequest struct {
	Model  string `json:"model"`
	Prompt string `json:"prompt"`
	Stream bool   `json:"stream"`
}

// GenerateResponse mendefinisikan bentuk response dari Ollama API.
type GenerateResponse struct {
	Response string `json:"response"`
}

// ClipTimestamp adalah hasil ekstraksi dari output LLM.
type ClipTimestamp struct {
	StartTime string `json:"start_time"`
	EndTime   string `json:"end_time"`
	Reasoning string `json:"reasoning"`
}

// NewClient menginisialisasi client Ollama.
func NewClient(baseURL string, model string) *Client {
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}
	if model == "" {
		model = "llama3.2"
	}
	return &Client{
		baseURL: baseURL,
		model:   model,
		httpClient: &http.Client{
			Timeout: 120 * time.Second,
		},
	}
}

// normalizeTimestamp memastikan timestamp memiliki format HH:MM:SS.
func normalizeTimestamp(ts string) (string, error) {
	// Hapus karakter kurung siku atau kutip jika LLM tak sengaja menyertakannya
	ts = strings.Trim(ts, "[]\"' ")

	if regexp.MustCompile(`^\d{2}:\d{2}:\d{2}$`).MatchString(ts) {
		return ts, nil
	}
	if regexp.MustCompile(`^\d{2}:\d{2}$`).MatchString(ts) {
		return "00:" + ts, nil // Asumsi menit:detik, prepend jam
	}
	return "", fmt.Errorf("invalid timestamp format: %s", ts)
}

// FindTimestamps mengirimkan transcript ke Ollama dan mendapatkan timestamp klip terbaik.
func (c *Client) FindTimestamps(ctx context.Context, transcriptChunk string) (*ClipTimestamp, error) {
	log.Println("[OLLAMA] Calling local LLM to find best timestamps")

	prompt := fmt.Sprintf(`You are a video editor assistant. The transcript below contains time markers in [HH:MM:SS] format. Use ONLY these time markers to find the most engaging 60-120 second portion for a short-form vertical video clip.
If the transcript appears to be song lyrics or poetry, select the most continuous stanza (like a chorus) as the most engaging part.

TRANSCRIPT:
%s

Rules:
1. Your start_time and end_time MUST come from the [HH:MM:SS] markers in the transcript above.
2. Do NOT invent timestamps. Only use timestamps that appear in the transcript.
3. The clip duration must be between 60 and 120 seconds.

Respond with ONLY valid JSON, no other text:
{"start_time": "HH:MM:SS", "end_time": "HH:MM:SS", "reasoning": "..."}`, transcriptChunk)

	reqPayload := GenerateRequest{
		Model:  c.model,
		Prompt: prompt,
		Stream: false,
	}

	payloadBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/generate", bytes.NewReader(payloadBytes))
	if err != nil {
		return nil, fmt.Errorf("failed to create http request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call Ollama API: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		bodyErr, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("ollama API returned status %d: %s", resp.StatusCode, string(bodyErr))
	}

	var generateResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&generateResp); err != nil {
		return nil, fmt.Errorf("failed to decode response body: %w", err)
	}

	var clipTs ClipTimestamp
	if err := json.Unmarshal([]byte(generateResp.Response), &clipTs); err != nil {
		log.Printf("[OLLAMA] Failed to parse JSON response: %v. Raw response: %s", err, generateResp.Response)
		return nil, fmt.Errorf("failed to parse JSON from LLM: %w", err)
	}

	// Normalisasi start dan end time ke HH:MM:SS
	startNorm, err := normalizeTimestamp(clipTs.StartTime)
	if err != nil {
		return nil, fmt.Errorf("start_time normalization failed: %w", err)
	}
	clipTs.StartTime = startNorm

	endNorm, err := normalizeTimestamp(clipTs.EndTime)
	if err != nil {
		return nil, fmt.Errorf("end_time normalization failed: %w", err)
	}
	clipTs.EndTime = endNorm

	log.Printf("[OLLAMA] Successfully extracted timestamps: %s to %s", clipTs.StartTime, clipTs.EndTime)
	return &clipTs, nil
}
