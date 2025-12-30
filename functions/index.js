const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// ------------------- HELPER FUNCTION -------------------
function getDiffDays(expiryDate) {
  const today = new Date();
  const expiry = new Date(expiryDate);
  expiry.setHours(0, 0, 0, 0);
  today.setHours(0, 0, 0, 0);

  const diffTime = expiry.getTime() - today.getTime();
  return Math.round(diffTime / (1000 * 60 * 60 * 24));
}

async function createAlertForBatch(db, batch) {
  if (!batch.expiryDate || !batch.productId) return;

  const batchId = batch.id || batch.batchId;
  const diffDays = getDiffDays(batch.expiryDate.toDate ? batch.expiryDate.toDate() : batch.expiryDate);

  let stage = null;
  if (diffDays === 5) stage = "5";
  else if (diffDays === 3) stage = "3";
  else if (diffDays === 0) stage = "expired";
  else return;

  // Prevent duplicate alerts
  const exists = await db.collection("alerts")
    .where("batchId", "==", batchId)
    .where("expiryStage", "==", stage)
    .limit(1)
    .get();

  if (!exists.empty) return;

  // Get product info
  const productSnap = await db.collection("products").doc(batch.productId).get();
  if (!productSnap.exists) return;

  const productName = productSnap.data().productName;

  const alertData = {
    batchId,
    productId: batch.productId,
    productName,
    batchNumber: batch.batchNumber,
    expiryStage: stage,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Create alert in Firestore
  const alertRef = await db.collection("alerts").add(alertData);
  console.log(`✅ Alert created for ${productName} (${stage})`);

  // Send push notification immediately
  await admin.messaging().send({
    notification: {
      title: "⚠️ Expiry Alert",
      body: stage === "expired"
        ? `URGENT: ${productName} has expired!`
        : `${productName} (Batch ${batch.batchNumber}) expires in ${stage} days.`
    },
    data: {
      batchId,
      productId: batch.productId,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    topic: "manager_alerts",
  });

  console.log(`✅ Push notification sent for ${productName} (${stage})`);
}

// ------------------- TRIGGER ON BATCH CREATE/UPDATE -------------------
exports.createExpiryAlertOnBatchChange = onDocumentWritten(
  "batches/{batchId}",
  async (event) => {
    const batch = event.data?.after?.data();
    if (!batch) return;
    batch.id = event.data.after.id; // add id for helper function

    const db = admin.firestore();
    await createAlertForBatch(db, batch);
  }
);

// ------------------- DAILY JOB TO CREATE ALERTS -------------------
exports.createExpiryAlertsDaily = onSchedule(
  {
    schedule: "every day 00:00",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const db = admin.firestore();
    const batchesSnapshot = await db.collection("batches").get();

    for (const doc of batchesSnapshot.docs) {
      const batch = doc.data();
      batch.id = doc.id;
      await createAlertForBatch(db, batch);
    }
  }
);
