const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// ==========================================================
<<<<<<< HEAD
// 1. RISK ANALYSIS TRIGGER (UPDATED)
=======
// 1. DELETE USER & DATA (Region: Singapore)
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
// ==========================================================
exports.deleteUserAndData = onCall({ region: "asia-southeast1" }, async (request) => {
  const userIdToDelete = request.data.userIdToDelete;

  if (!userIdToDelete) {
    throw new HttpsError("invalid-argument", "The function must be called with a userIdToDelete.");
  }

  try {
    await admin.auth().deleteUser(userIdToDelete);
    await admin.firestore().collection("users").doc(userIdToDelete).delete();
    console.log(`Successfully deleted user: ${userIdToDelete}`);
    return { status: "success", message: "User deleted successfully" };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ==========================================================
// 2. RISK ANALYSIS TRIGGER (Region: Singapore)
// ==========================================================
exports.onRiskAnalysisWritten = onDocumentWritten({
  document: "risk_analysis/{riskId}",
  region: "asia-southeast1"
}, async (event) => {
  const db = admin.firestore();
  const snapshot = event.data.after;

  if (!snapshot || !snapshot.exists) return null;

  const riskData = snapshot.data();
  const riskLevel = riskData.RiskLevel;

  if (riskLevel === "High" || riskLevel === "Medium") {
    const riskId = event.params.riskId;

    const existing = await db.collection("alerts")
      .where("riskAnalysisId", "==", riskId)
      .where("isDone", "==", false)
      .get();

    if (!existing.empty) return null;

<<<<<<< HEAD
    // 🔹 FIX: We must include productId so Flutter can find the Category/SubCategory
    // Based on your risk_analysis structure, the document ID (riskId) IS usually the productId.
=======
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
    const alertData = {
      alertType: "risk",
      riskLevel: riskLevel,
      riskValue: riskData.RiskValue || 0,
      riskAnalysisId: riskId,
<<<<<<< HEAD
      productId: riskId, // 🔹 ADDED THIS: Mapping riskId to productId for lookup
=======
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
      productName: riskData.ProductName || "Unknown Product",
      isRead: false,
      isDone: false,
      isNotified: true,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await db.collection("alerts").add(alertData);
      const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });
      const emoji = riskLevel === "High" ? "🔥" : "⚠️"; // Updated emoji to match your Flutter code

      return admin.messaging().send({
        notification: {
          title: `${emoji} ${riskLevel.toUpperCase()} RISK ALERT          ${dateStr}`,
          body: `"${alertData.productName}" has a Risk Score of ${alertData.riskValue}/100.`,
        },
        data: {
          riskAnalysisId: riskId,
          productId: riskId, // Pass productId in data payload as well
          alertType: "risk",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        topic: "inventory_alerts",
      });
    } catch (error) {
      console.error("Risk Alert Error:", error);
      return null;
    }
  }
  return null;
});

// ==========================================================
<<<<<<< HEAD
// 2. EXPIRY ALERT LOGIC (REMAINS THE SAME)
=======
// 3. EXPIRY ALERT HELPER & TRIGGERS (Region: Singapore)
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
// ==========================================================
async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return null;

<<<<<<< HEAD
  const msiaDateString = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Kuala_Lumpur",
  });
=======
  const msiaDateString = new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kuala_Lumpur" });
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
  const today = new Date(msiaDateString);

  const expDate = batch.expiryDate.toDate();
  const expDateString = expDate.toLocaleDateString("en-CA", { timeZone: "Asia/Kuala_Lumpur" });
  const expiry = new Date(expDateString);

  const diffTime = expiry.getTime() - today.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

  let stage = null;
  if (diffDays <= 0) stage = "expired";
  else if (diffDays === 3) stage = "3";
  else if (diffDays === 5) stage = "5";
  else return null;

  const exists = await db.collection("alerts")
    .where("batchId", "==", batchId)
    .where("expiryStage", "==", stage)
    .get();

  if (!exists.empty) return null;

  const productSnap = await db.collection("products").doc(batch.productId).get();
  const productData = productSnap.exists ? productSnap.data() : { productName: "Unknown" };

  const alertData = {
    alertType: "expiry",
    expiryStage: stage,
    isRead: false,
    isDone: false,
    isNotified: true,
    notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    batchId: batchId,
    batchNumber: batch.batchNumber || "N/A",
    productId: batch.productId,
    productName: productData.productName || "Unknown Product",
  };

  try {
    await db.collection("alerts").add(alertData);
    const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });
    let title = stage === "expired" ? `🔔 EXPIRED PRODUCT` : `🔔 EXPIRY SOON (${stage} Days Left)`;

    return admin.messaging().send({
      notification: {
        title: `${title}          ${dateStr}`,
        body: `"${alertData.productName}"\nBatch: ${alertData.batchNumber}`,
      },
      data: {
        batchId: batchId,
        productId: batch.productId,
        stage: String(stage),
        alertType: "expiry",
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      },
      topic: "inventory_alerts",
    });
  } catch (error) {
    console.error("Error:", error);
    return null;
  }
}

<<<<<<< HEAD
exports.onBatchChange = onDocumentWritten("batches/{batchId}", async (event) => {
=======
exports.onBatchChange = onDocumentWritten({
  document: "batches/{batchId}",
  region: "asia-southeast1"
}, async (event) => {
>>>>>>> 92f7c80335241b617c9ab25174dffc5fddc2d079
  const db = admin.firestore();
  const snapshot = event.data.after;
  if (!snapshot || !snapshot.exists) return null;
  return createAlertForBatch(db, snapshot.data(), event.params.batchId);
});

exports.dailyExpiryCheck = onSchedule({
  schedule: "every day 00:00",
  timeZone: "Asia/Kuala_Lumpur",
}, async () => {
  const db = admin.firestore();
  const snapshot = await db.collection("batches").get();
  const promises = [];
  snapshot.forEach(doc => {
    promises.push(createAlertForBatch(db, doc.data(), doc.id));
  });
  return Promise.all(promises);
});