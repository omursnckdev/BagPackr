const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();

exports.sendFirestoreNotification = onDocumentCreated(
    "notifications/{docId}",
    async (event) => {
      const data = event.data.data();
      const docId = event.params.docId;

      console.log("🔔 New notification document created:", docId);
      console.log("📦 Notification data:", data);

      if (!data.token) {
        console.error("❌ No token provided in notification document");
        return;
      }

      const message = {
        token: data.token,
        notification: {
          title: data.title,
          body: data.body,
        },
        // Add custom data to the notification
        data: data.data || {},
      };

      try {
        const response = await getMessaging().send(message);
        console.log("✅ Notification sent successfully:", response);

        // Delete the notification document after successful send
        await getFirestore().collection("notifications").doc(docId).delete();
        console.log("🗑️ Notification document deleted");
      } catch (error) {
        console.error("❌ Error sending notification:", error);
        console.error("❌ Error code:", error.code);
        console.error("❌ Error message:", error.message);

        // Optionally: Mark the document as failed instead of deleting
        await getFirestore().collection("notifications").doc(docId).update({
          error: error.message,
          errorCode: error.code,
          failed: true,
        });
      }
    },
);
