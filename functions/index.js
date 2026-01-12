const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

// ==========================================================
// 1. DELETE USER & DATA (Region: Singapore)
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

    const alertData = {
      alertType: "risk",
      riskLevel: riskLevel,
      riskValue: riskData.RiskValue || 0,
      riskAnalysisId: riskId,
      productName: riskData.ProductName || "Unknown Product",
      isRead: false,
      isDone: false,
      isNotified: true,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      await db.collection("alerts").add(alertData);
      const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });
      const emoji = riskLevel === "High" ? "🔥" : "⚠️";

      return admin.messaging().send({
        notification: {
          title: `${emoji} ${riskLevel.toUpperCase()} RISK ALERT          ${dateStr}`,
          body: `"${alertData.productName}" has a Risk Score of ${alertData.riskValue}/100.`,
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
// 3. EXPIRY ALERT HELPER & TRIGGERS (Region: Singapore)
// ==========================================================
async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return null;

  const msiaDateString = new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kuala_Lumpur" });
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
      topic: "inventory_alerts",
    });
  } catch (error) {
    console.error("Error:", error);
    return null;
  }
}

exports.onBatchChange = onDocumentWritten({
  document: "batches/{batchId}",
  region: "asia-southeast1"
}, async (event) => {
  const db = admin.firestore();
  const snapshot = event.data.after;
  if (!snapshot || !snapshot.exists) return null;
  return createAlertForBatch(db, snapshot.data(), event.params.batchId);
});

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

// ==========================================================
// 4. LOW STOCK TRIGGER (Region: Singapore)
// ==========================================================
exports.onLowStockTrigger = onDocumentWritten({
  document: "products/{productId}",
  region: "asia-southeast1"
}, async (event) => {
  const db = admin.firestore();
  const snapshot = event.data.after;

  if (!snapshot || !snapshot.exists) return null;

  const productData = snapshot.data();
  const currentStock = parseInt(productData.currentStock || 0);
  const reorderLevel = parseInt(productData.reorderLevel || 0);
  const productId = event.params.productId;

  // 🔹 AUTO-RESET LOGIC
  if (currentStock > reorderLevel) {
    const activeAlerts = await db.collection("alerts")
      .where("productId", "==", productId)
      .where("alertType", "==", "lowStock")
      .where("isDone", "==", false)
      .get();

    if (!activeAlerts.empty) {
      const batch = db.batch();
      activeAlerts.forEach((doc) => {
        batch.update(doc.ref, {
          isDone: true,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          reason: "Stock replenished above reorder level"
        });
      });
      await batch.commit();
      console.log(`Resolved existing alerts for ${productId}`);
    }
    return null;
  }

  // 🔹 TRIGGER LOGIC
  if (currentStock <= reorderLevel) {
    const existing = await db.collection("alerts")
      .where("productId", "==", productId)
      .where("alertType", "==", "lowStock")
      .where("isDone", "==", false)
      .get();

    if (!existing.empty) return null;

    const alertData = {
      alertType: "lowStock",
      productId: productId,
      productName: productData.productName || "Unknown Product",
      currentStock: currentStock,
      reorderLevel: reorderLevel,
      category: productData.category || "N/A",
      subCategory: productData.subCategory || "N/A",
      imageUrl: productData.imageUrl || "",
      isRead: false,
      isDone: false,
      isNotified: true,
      notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      // 🔹 CAPTURE THE ALERT ID: We need this for the detail page navigation
      const alertRef = await db.collection("alerts").add(alertData);
      const newAlertId = alertRef.id;

      const dateStr = new Date().toLocaleDateString("en-GB", { timeZone: "Asia/Kuala_Lumpur" });

      return admin.messaging().send({
        notification: {
          title: `📉 LOW STOCK ALERT          ${dateStr}`,
          body: `"${alertData.productName}" is at or below reorder level (${currentStock} left).`,
        },
        data: {
          productId: productId,
          alertId: newAlertId, // 🔹 PASS ALERT ID TO FLUTTER
          alertType: "lowStock",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        topic: "inventory_alerts",
      });
    } catch (error) {
      console.error("Low Stock Alert Error:", error);
      return null;
    }
  }
  return null;
});