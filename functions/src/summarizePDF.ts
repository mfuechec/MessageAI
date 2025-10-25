import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import {checkRateLimit} from "./utils/rateLimiting";

// Initialize OpenAI with API key from environment
const openai = new OpenAI({
  apiKey: functions.config().openai?.api_key || process.env.OPENAI_API_KEY,
});

/**
 * Cloud Function: Summarize PDF Document
 *
 * Generates an AI summary of a PDF document using OpenAI GPT-4.
 * Results are cached by document URL to avoid re-processing the same PDF.
 *
 * Input: { documentUrl: string, documentText: string }
 * Output: { success: boolean, summary: string, cached: boolean, timestamp: string }
 */
export const summarizePDF = functions
  .runWith({
    timeoutSeconds: 30,
    memory: "512MB",
  })
  .https.onCall(async (data, context) => {
    try {
      // ========================================
      // 1. AUTHENTICATION CHECK
      // ========================================
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const userId = context.auth.uid;

      // ========================================
      // 2. INPUT VALIDATION
      // ========================================
      if (!data.documentUrl || typeof data.documentUrl !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "documentUrl must be a non-empty string"
        );
      }

      if (!data.documentText || typeof data.documentText !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "documentText must be a non-empty string"
        );
      }

      const documentUrl = data.documentUrl;
      const documentText = data.documentText;

      console.log(
        `[summarizePDF] User ${userId} requesting summary for document`,
        `Text length: ${documentText.length} characters`
      );

      // ========================================
      // 3. RATE LIMITING
      // ========================================
      // Check rate limit BEFORE expensive operations to prevent abuse
      await checkRateLimit(userId, "pdf_summary", 50); // 50 PDF summaries per day

      // ========================================
      // 4. SMART CACHE LOOKUP
      // ========================================
      // Use document URL as cache key (PDFs are immutable)
      const cacheKey = Buffer.from(documentUrl).toString("base64").substring(0, 100);

      const cacheDoc = await admin.firestore()
        .collection("ai_cache")
        .doc(`pdf_${cacheKey}`)
        .get();

      if (cacheDoc.exists) {
        const cacheData = cacheDoc.data();

        // Check if cache has expired (30 days for PDFs)
        const expiresAt = cacheData?.expiresAt;
        const isExpired = expiresAt && (
          expiresAt.toDate ? expiresAt.toDate() : new Date(expiresAt)
        ) < new Date();

        if (!isExpired) {
          console.log(`[summarizePDF] Returning cached summary`);
          const cachedResult = JSON.parse(cacheData!.result);

          return {
            success: true,
            summary: cachedResult.summary,
            cached: true,
            timestamp: cacheData!.generatedAt?.toDate?.().toISOString() || new Date().toISOString(),
          };
        }
      }

      console.log(`[summarizePDF] No cache found - generating new summary`);

      // ========================================
      // 5. PREPARE TEXT FOR AI
      // ========================================
      // Truncate to ~4000 tokens (approximately 16,000 characters)
      const maxLength = 16000;
      const truncatedText = documentText.length > maxLength
        ? documentText.substring(0, maxLength) + "\n\n[Document truncated for summarization...]"
        : documentText;

      console.log(`[summarizePDF] Prepared ${truncatedText.length} characters for OpenAI`);

      // ========================================
      // 6. OPENAI API CALL
      // ========================================
      let aiSummary: string;

      try {
        const completion = await openai.chat.completions.create({
          model: "gpt-4o-mini",
          temperature: 0.3, // Lower = more deterministic
          max_tokens: 200,  // 3-5 sentences
          messages: [
            {
              role: "system",
              content: `You are an AI assistant that summarizes PDF documents.
Your summaries MUST be:
- Exactly 3-5 sentences (60-100 words)
- Cover the main points and purpose of the document
- Use clear, professional language
- Focus on key takeaways and conclusions`,
            },
            {
              role: "user",
              content: `Please provide a 3-5 sentence summary of this document:\n\n${truncatedText}`,
            },
          ],
        });

        aiSummary = completion.choices[0]?.message?.content?.trim() || "";

        if (!aiSummary) {
          throw new Error("OpenAI returned empty summary");
        }

        console.log(`[summarizePDF] OpenAI summary generated: ${aiSummary.substring(0, 100)}...`);
      } catch (error: any) {
        console.error(`[summarizePDF] OpenAI API error:`, error);

        // Handle rate limiting from OpenAI
        if (error.status === 429) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "AI service rate limit exceeded. Please try again later."
          );
        }

        // Handle quota exceeded
        if (error.status === 429 || error.code === "insufficient_quota") {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "AI service quota exceeded. Please contact support."
          );
        }

        throw new functions.https.HttpsError(
          "internal",
          `Failed to generate summary: ${error.message}`
        );
      }

      // ========================================
      // 7. CACHE THE RESULT
      // ========================================
      const result = {
        summary: aiSummary,
      };

      await admin.firestore()
        .collection("ai_cache")
        .doc(`pdf_${cacheKey}`)
        .set({
          result: JSON.stringify(result),
          documentUrl: documentUrl,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
          userId: userId,
        });

      console.log(`[summarizePDF] Cached summary for 30 days`);

      // ========================================
      // 8. RETURN RESULT
      // ========================================
      return {
        success: true,
        summary: aiSummary,
        cached: false,
        timestamp: new Date().toISOString(),
      };
    } catch (error: any) {
      // HttpsError already thrown - rethrow as-is
      if (error.code && error.message) {
        throw error;
      }

      // Unknown error - wrap it
      console.error(`[summarizePDF] Unexpected error:`, error);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to summarize PDF: ${error.message || "Unknown error"}`
      );
    }
  });
