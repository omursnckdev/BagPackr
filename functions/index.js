// Load environment variables from .env
require("dotenv").config();

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");

admin.initializeApp();

// -------------------------
// Generate Itinerary Function
// -------------------------
exports.generateItinerary = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to generate itinerary",
    );
  }

  try {
    // ✅ Use environment variable instead of functions.config()
    const apiKey = process.env.GEMINI_KEY;
    if (!apiKey) {
      throw new functions.https.HttpsError(
          "internal",
          "Missing GEMINI_KEY environment variable",
      );
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({model: "gemini-2.0-flash-exp"});

    const {location, duration, interests, budgetPerDay} = data;

    if (!location || !duration || !interests || !budgetPerDay) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required parameters",
      );
    }

    // Prompt
    const prompt = `Create a ${duration}-day itinerary for ${location}.

Interests: ${interests.join(", ")}
Daily budget: $${Math.floor(budgetPerDay)}

Rules:
- 4-5 activities per day with variety
- Real place names in ${location}
- Include time (e.g., "09:00 AM - 11:00 AM"), distance (km), and cost ($)
- Daily costs should total ~$${Math.floor(budgetPerDay)}
- Don't repeat similar activities

Return ONLY this JSON (no markdown):
{
  "dailyPlans": [
    {
      "day": 1,
      "activities": [
        {
          "name": "Place Name",
          "type": "Beach/Restaurant/Museum/etc",
          "description": "Brief description",
          "time": "09:00 AM - 11:00 AM",
          "distance": 2.5,
          "cost": 25.0
        }
      ]
    }
  ]
}`;

    // Call Gemini
    const result = await model.generateContent(prompt);
    const text = result.response.text();

    // Clean JSON
    const cleanedText = text
        .replace(/```json/g, "")
        .replace(/```/g, "")
        .trim();

    let parsedData;
    try {
      parsedData = JSON.parse(cleanedText);
    } catch (err) {
      console.error("JSON Parse Error:", err);
      throw new functions.https.HttpsError(
          "internal",
          "Failed to parse AI response",
      );
    }

    return {success: true, data: parsedData};
  } catch (error) {
    console.error("Error generating itinerary:", error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
        "internal",
        "Failed to generate itinerary: " + error.message,
    );
  }
});

// -------------------------
// Get API Usage Function
// -------------------------
exports.getApiUsage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Not authenticated",
    );
  }

  const userId = context.auth.uid;

  try {
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

    const userData = userDoc.data() || {};

    return {
      itinerariesGenerated: userData.itinerariesGenerated || 0,
      lastGenerated: userData.lastGenerated || null,
    };
  } catch (error) {
    console.error("Error fetching API usage:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to fetch API usage",
    );
  }
});
