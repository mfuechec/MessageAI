import * as functions from "firebase-functions";
import OpenAI from "openai";

/**
 * Test Cloud Function: Validate OpenAI API Configuration
 *
 * Epic 6 (Story 6.0) - Environment Setup
 *
 * Purpose: Verify OpenAI API key is configured correctly and can generate embeddings
 *
 * Test Call:
 * firebase functions:call testOpenAI --data '{}'
 */
export const testOpenAI = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to test OpenAI configuration"
    );
  }

  console.log(`Testing OpenAI API configuration for user: ${context.auth.uid}`);

  try {
    // Initialize OpenAI client
    const openai = new OpenAI({
      apiKey: functions.config().openai.api_key,
    });

    console.log("OpenAI client initialized successfully");

    // Test embedding generation
    const testInput = "This is a test message to verify OpenAI API connectivity";
    const startTime = Date.now();

    const response = await openai.embeddings.create({
      model: "text-embedding-ada-002",
      input: testInput,
    });

    const endTime = Date.now();
    const latency = endTime - startTime;

    console.log(`OpenAI API call successful. Latency: ${latency}ms`);

    // Validate response
    if (!response.data || response.data.length === 0) {
      throw new Error("No embedding data returned from OpenAI");
    }

    const embedding = response.data[0].embedding;

    return {
      success: true,
      message: "OpenAI API configured correctly!",
      details: {
        embeddingLength: embedding.length,
        expectedLength: 1536,
        latencyMs: latency,
        model: response.model,
        usage: response.usage,
      },
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    console.error("Error testing OpenAI API:", error);

    // Handle specific OpenAI errors
    if (error.status === 401) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Invalid OpenAI API key. Please check configuration."
      );
    }

    if (error.status === 429) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "OpenAI rate limit exceeded. Please try again later."
      );
    }

    // Generic error
    throw new functions.https.HttpsError(
      "internal",
      `Failed to test OpenAI API: ${error.message}`
    );
  }
});
