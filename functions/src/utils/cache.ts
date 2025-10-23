import * as admin from "firebase-admin";

/**
 * Generate a cache key for AI results
 *
 * @param featureType - Type of AI feature ('summary', 'actionItems', 'search')
 * @param conversationId - Conversation ID
 * @param messageIdentifier - Latest message ID or query hash
 * @returns Cache key string
 */
export function generateCacheKey(
  featureType: string,
  conversationId: string,
  messageIdentifier: string
): string {
  return `${featureType}_${conversationId}_${messageIdentifier}`;
}

/**
 * Check if a cache entry has expired
 *
 * @param cacheData - Cache document data
 * @returns true if expired, false otherwise
 */
export function isCacheExpired(cacheData: admin.firestore.DocumentData): boolean {
  const expiresAt = cacheData.expiresAt;

  if (!expiresAt) {
    return true; // No expiration set, consider expired
  }

  const expirationDate = expiresAt.toDate ? expiresAt.toDate() : new Date(expiresAt);
  return expirationDate < new Date();
}

/**
 * Lookup cached AI result
 *
 * @param cacheKey - The cache key to look up
 * @returns Cached result if found and not expired, null otherwise
 */
export async function lookupCache(
  cacheKey: string
): Promise<any | null> {
  const cacheDoc = await admin.firestore()
    .collection("ai_cache")
    .doc(cacheKey)
    .get();

  if (!cacheDoc.exists) {
    console.log(`Cache miss: ${cacheKey}`);
    return null;
  }

  const cacheData = cacheDoc.data();
  if (!cacheData) {
    return null;
  }

  // Check expiration
  if (isCacheExpired(cacheData)) {
    console.log(`Cache expired: ${cacheKey}`);
    // Delete expired cache entry
    await admin.firestore()
      .collection("ai_cache")
      .doc(cacheKey)
      .delete();
    return null;
  }

  console.log(`Cache hit: ${cacheKey}`);
  return JSON.parse(cacheData.result);
}

/**
 * Store AI result in cache
 *
 * @param cacheKey - The cache key
 * @param result - The result to cache (will be JSON stringified)
 * @param featureType - Type of AI feature
 * @param conversationId - Conversation ID
 * @param messageCount - Number of messages processed
 * @param expirationHours - Hours until cache expires (default: 24)
 */
export async function storeInCache(
  cacheKey: string,
  result: any,
  featureType: string,
  conversationId: string,
  messageCount: number,
  expirationHours: number = 24
): Promise<void> {
  const expiresAt = new Date(Date.now() + expirationHours * 60 * 60 * 1000);

  await admin.firestore()
    .collection("ai_cache")
    .doc(cacheKey)
    .set({
      featureType,
      conversationId,
      messageCount,
      result: JSON.stringify(result),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      schemaVersion: 1,
    });

  console.log(`Stored in cache: ${cacheKey}, expires: ${expiresAt.toISOString()}`);
}

/**
 * Generate a simple hash for a string (used for search query caching)
 *
 * @param str - String to hash
 * @returns Hash string
 */
export function simpleHash(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash).toString(36);
}
