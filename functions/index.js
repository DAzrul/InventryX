const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendExpiryNotification = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const data = event.data.data();

    let title = "⚠️ Expiry Alert";
    let body = "";

    // Customize the message based on the stage
    if (data.expiryStage === "expired") {
      body = `URGENT: ${data.productName} has expired!`;
    } else {
      body = `${data.productName} (Batch ${data.batchNumber}) expires in ${data.expiryStage} days.`;
    }

    const message = {
      "notification": {
          "title": "⚠️ Expiry Alert",
          "body": "Product X expires in 3 days"
        },
        "data": {
          "batchId": "...",
          "productId": "...",
          "click_action": "FLUTTER_NOTIFICATION_CLICK"
        },
      topic: "manager_alerts",
    };

    try {
      await admin.messaging().send(message);
      console.log(`Notification sent for ${data.productName} at stage ${data.expiryStage}`);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);