const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

<<<<<<< HEAD
// ==========================================================
// 1. RISK ANALYSIS TRIGGER (NEW)
// ==========================================================
exports.onRiskAnalysisWritten = onDocumentWritten("risk_analysis/{riskId}", async (event) => {
  const db = admin.firestore();
  const snapshot = event.data.after;

  if (!snapshot || !snapshot.exists) return null;

  const riskData = snapshot.data();
  const riskLevel = riskData.RiskLevel; // "High" or "Medium"

  // Only alert for High or Medium risk
  if (riskLevel === "High" || riskLevel === "Medium") {
    const riskId = event.params.riskId;

    // Check if an unhandled alert for this risk already exists to avoid spam
    const existing = await db.collection("alerts")
      .where("riskAnalysisId", "==", riskId)
      .where("isDone", "==", false)
      .get();

    if (!existing.empty) return null;

    // Structure for Risk Alert (Omits batchId and expiryStage)
    const alertData = {
      alertType: "risk",
      riskLevel: riskLevel,
      riskValue: riskData.RiskValue || 0,
      riskAnalysisId: riskId, // ID from risk_analysis collection
      productName: riskData.ProductName || "Unknown Product",
      isRead: false,
      isDone: false,
      isNotified: true,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await db.collection("alerts").add(alertData);

      const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });
      const emoji = riskLevel === "High" ? "⚠️" : "💡";

      return admin.messaging().send({
        notification: {
          title: `${emoji} ${riskLevel.toUpperCase()} RISK ALERT          ${dateStr}`,
          body: `"${alertData.productName}" has a Risk Score of ${alertData.riskValue}/100. Tap for details.`,
        },
        data: {
          riskAnalysisId: riskId,
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
// 2. EXPIRY ALERT LOGIC (EXISTING)
// ==========================================================
=======
// --- DELETE USER & DATA (Region: Singapore) ---
exports.deleteUserAndData = onCall({ region: "asia-southeast1" }, async (request) => {
  const userIdToDelete = request.data.userIdToDelete;

  if (!userIdToDelete) {
    throw new HttpsError("invalid-argument", "The function must be called with a userIdToDelete.");
  }

  try {
    // 1. Delete dari Firebase Auth
    await admin.auth().deleteUser(userIdToDelete);

    // 2. Delete document dari Firestore
    await admin.firestore().collection("users").doc(userIdToDelete).delete();

    console.log(`Successfully deleted user: ${userIdToDelete} from Singapore region`);
    return { status: "success", message: "User deleted successfully" };
  } catch (error) {
    console.error("Error deleting user:", error);
    throw new HttpsError("internal", error.message);
  }
});

// --- HELPER FUNCTION UNTUK ALERT ---
>>>>>>> e244d6a6aec4b2818ccdf157dd2affa7c70900ce
async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return null;

<<<<<<< HEAD
  const msiaDateString = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Kuala_Lumpur",
  });
  const today = new Date(msiaDateString);
=======
  const today = new Date();
  today.setHours(0, 0, 0, 0);
>>>>>>> e244d6a6aec4b2818ccdf157dd2affa7c70900ce

  const expDate = batch.expiryDate.toDate();
  const expDateString = expDate.toLocaleDateString("en-CA", {
    timeZone: "Asia/Kuala_Lumpur",
  });
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

<<<<<<< HEAD
  try {
    await db.collection("alerts").add(alertData);
    const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });
    let title = stage === "expired" ? `🔔 EXPIRED PRODUCT` : `🔔 EXPIRY SOON (${stage} Days Left)`;

    return admin.messaging().send({
      notification: {
        title: `${title}          ${dateStr}`,
        body: `"${alertData.productName}"\nBatch: ${alertData.batchNumber}\nTap for details`,
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
=======
  await db.collection("alerts").add(alertData);

  const now = new Date();
  const dateStr = `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth() + 1).padStart(2, '0')}/${now.getFullYear()}`;

  let notificationTitle = stage === "expired"
    ? `🔔 EXPIRED PRODUCT          ${dateStr}`
    : `🔔 EXPIRY SOON (${stage} Days Left)          ${dateStr}`;

  const notificationBody = `"${productData.productName}"\n"${productData.subCategory}"\n"${batch.batchNumber || "N/A"}"\nTap for more details`;

  await admin.messaging().send({
    notification: { title: notificationTitle, body: notificationBody },
    data: { batchId, productId: batch.productId, stage, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    topic: "manager_alerts",
  });
>>>>>>> e244d6a6aec4b2818ccdf157dd2affa7c70900ce
}

// --- BATCH CHANGE (Region: Singapore) ---
exports.onBatchChange = onDocumentWritten({
  document: "batches/{batchId}",
  region: "asia-southeast1"
}, async (event) => {
  const db = admin.firestore();
<<<<<<< HEAD
  const snapshot = event.data.after;
  if (!snapshot || !snapshot.exists) return null;
  return createAlertForBatch(db, snapshot.data(), event.params.batchId);
=======
  const batch = event.data.after.data();
  if (!batch) return;
  await createAlertForBatch(db, batch, event.params.batchId);
>>>>>>> e244d6a6aec4b2818ccdf157dd2affa7c70900ce
});

// --- DAILY SCHEDULE (Region: Singapore) ---
exports.dailyExpiryCheck = onSchedule({
  schedule: "every day 00:00",
  timeZone: "Asia/Kuala_Lumpur",
  region: "asia-southeast1",
}, async () => {
  const db = admin.firestore();
  const snapshot = await db.collection("batches").get();
  const promises = [];
  snapshot.forEach(doc => {
    promises.push(createAlertForBatch(db, doc.data(), doc.id));
  });
  return Promise.all(promises);
});