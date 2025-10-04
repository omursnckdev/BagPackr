const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

exports.sendFirestoreNotification = onDocumentCreated(
    "notifications/{docId}",
    async (event) => {
      const data = event.data.data();
      const message = {
        token: data.token,
        notification: {title: data.title, body: data.body},
      };
      await getMessaging().send(message);
      console.log("✅ Push sent to:", data.token);
    },
);
