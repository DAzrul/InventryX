const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return;

  // --- Normalize Dates to Midnight ---
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const expiry = batch.expiryDate.toDate();
  expiry.setHours(0, 0, 0, 0);

  const diffTime = expiry.getTime() - today.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

  console.log(`Checking Batch ${batchId}: ${diffDays} days left`);

  let stage = null;
  if (diffDays <= 0) stage = "expired";
  else if (diffDays === 3) stage = "3";
  else if (diffDays === 5) stage = "5";
  else return;

  // --- Prevent Duplicates ---
  const exists = await db.collection("alerts")
    .where("batchId", "==", batchId)
    .where("expiryStage", "==", stage)
    .get();

  if (!exists.empty) return;

  // --- Get Product Info (including subCategory) ---
  const productSnap = await db.collection("products").doc(batch.productId).get();
  const productData = productSnap.exists ? productSnap.data() : { productName: "Unknown", subCategory: "N/A" };

  // --- CREATE ALERT DOCUMENT ---
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
    productName: productData.productName,
  };

  await db.collection("alerts").add(alertData);
  console.log(`✅ Alert Stored: ${productData.productName} (Stage: ${stage})`);

  // --- PREPARE STYLED NOTIFICATION ---

  // Format current date as DD/MM/YYYY
  const now = new Date();
  const dateStr = `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth() + 1).padStart(2, '0')}/${now.getFullYear()}`;

  let notificationTitle = "";
  if (stage === "expired") {
    notificationTitle = `🔔 EXPIRED PRODUCT          ${dateStr}`;
  } else {
    notificationTitle = `🔔 EXPIRY SOON (${stage} Days Left)          ${dateStr}`;
  }

  const notificationBody = `"${productData.productName}"\n"${productData.subCategory}"\n"${batch.batchNumber || "N/A"}"\nTap for more details`;

  // --- SEND PUSH ---
  await admin.messaging().send({
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    // Pass data for Flutter navigation
    data: {
      batchId: batchId,
      productId: batch.productId,
      stage: stage,
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    },
    topic: "manager_alerts",
  });
}

exports.onBatchChange = onDocumentWritten("batches/{batchId}", async (event) => {
  const db = admin.firestore();
  const batch = event.data.after.data();
  const batchId = event.params.batchId;
  if (!batch) return;
  await createAlertForBatch(db, batch, batchId);
});

exports.dailyExpiryCheck = onSchedule({
  schedule: "every day 00:00",
  timeZone: "Asia/Kuala_Lumpur",
}, async () => {
  const db = admin.firestore();
  const snapshot = await db.collection("batches").get();
  for (const doc of snapshot.docs) {
    await createAlertForBatch(db, doc.data(), doc.id);
  }
});