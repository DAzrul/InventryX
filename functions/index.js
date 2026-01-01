const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

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
async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return null;

  const msiaDateString = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Kuala_Lumpur",
  });
  const today = new Date(msiaDateString);

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
}

exports.onBatchChange = onDocumentWritten("batches/{batchId}", async (event) => {
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