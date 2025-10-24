import OpenAI from "openai";
import * as functions from "firebase-functions";

/**
 * OpenAI Service
 * Wrapper for OpenAI API calls with error handling
 *
 * Story 6.2: RAG System for Full User Context
 */

let openaiClient: OpenAI | null = null;

/**
 * Get or initialize the OpenAI client
 */
function getOpenAIClient(): OpenAI {
  if (!openaiClient) {
    const apiKey = functions.config().openai?.api_key;

    if (!apiKey) {
      throw new Error("OpenAI API key not configured. Run: firebase functions:config:set openai.api_key=YOUR_KEY");
    }

    openaiClient = new OpenAI({
      apiKey: apiKey,
    });
  }

  return openaiClient;
}

/**
 * Generate embedding for a single text using OpenAI text-embedding-ada-002
 *
 * @param text - Text to embed
 * @returns Embedding vector (1536 dimensions)
 */
export async function generateEmbedding(text: string): Promise<number[]> {
  try {
    const client = getOpenAIClient();

    const response = await client.embeddings.create({
      model: "text-embedding-ada-002",
      input: text,
    });

    return response.data[0].embedding;
  } catch (error: any) {
    console.error("Error generating embedding:", error);

    // Handle rate limits
    if (error.status === 429) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "OpenAI rate limit exceeded. Please try again later."
      );
    }

    // Handle invalid API key
    if (error.status === 401) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Invalid OpenAI API key"
      );
    }

    // Generic error
    throw new functions.https.HttpsError(
      "internal",
      `Failed to generate embedding: ${error.message}`
    );
  }
}

/**
 * Generate embeddings for multiple texts in batch
 *
 * @param texts - Array of texts to embed
 * @returns Array of embedding vectors
 */
export async function generateEmbeddingsBatch(texts: string[]): Promise<number[][]> {
  try {
    const client = getOpenAIClient();

    const response = await client.embeddings.create({
      model: "text-embedding-ada-002",
      input: texts,
    });

    return response.data.map(item => item.embedding);
  } catch (error: any) {
    console.error("Error generating embeddings batch:", error);

    // Handle rate limits
    if (error.status === 429) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "OpenAI rate limit exceeded. Please try again later."
      );
    }

    // Handle invalid API key
    if (error.status === 401) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Invalid OpenAI API key"
      );
    }

    // Generic error
    throw new functions.https.HttpsError(
      "internal",
      `Failed to generate embeddings: ${error.message}`
    );
  }
}

/**
 * Call GPT-4 for notification analysis
 *
 * @param systemPrompt - System prompt defining AI behavior
 * @param userPrompt - User prompt with context and messages
 * @returns Parsed JSON response from GPT-4
 */
export async function analyzeWithGPT4(
  systemPrompt: string,
  userPrompt: string
): Promise<any> {
  try {
    const client = getOpenAIClient();

    const response = await client.chat.completions.create({
      model: "gpt-4-turbo",
      messages: [
        {
          role: "system",
          content: systemPrompt,
        },
        {
          role: "user",
          content: userPrompt,
        },
      ],
      temperature: 0.3, // More deterministic
      response_format: {type: "json_object"}, // Guarantee JSON output
    });

    const content = response.choices[0].message.content;
    if (!content) {
      throw new Error("Empty response from GPT-4");
    }

    return JSON.parse(content);
  } catch (error: any) {
    console.error("Error calling GPT-4:", error);

    // Handle rate limits
    if (error.status === 429) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "OpenAI rate limit exceeded. Please try again later."
      );
    }

    // Handle invalid API key
    if (error.status === 401) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Invalid OpenAI API key"
      );
    }

    // Handle timeout
    if (error.code === "ETIMEDOUT" || error.code === "ECONNABORTED") {
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "GPT-4 request timed out"
      );
    }

    // Generic error
    throw new functions.https.HttpsError(
      "internal",
      `Failed to analyze with GPT-4: ${error.message}`
    );
  }
}

/**
 * Calculate cosine similarity between two embedding vectors
 *
 * @param a - First embedding vector
 * @param b - Second embedding vector
 * @returns Similarity score (0 to 1)
 */
export function cosineSimilarity(a: number[], b: number[]): number {
  if (a.length !== b.length) {
    throw new Error("Vectors must have same length");
  }

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  normA = Math.sqrt(normA);
  normB = Math.sqrt(normB);

  if (normA === 0 || normB === 0) {
    return 0;
  }

  return dotProduct / (normA * normB);
}
