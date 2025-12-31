const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

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
async function createAlertForBatch(db, batch, batchId) {
  if (!batch.expiryDate || !batch.productId) return;

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const expiry = batch.expiryDate.toDate();
  expiry.setHours(0, 0, 0, 0);

  const diffTime = expiry.getTime() - today.getTime();
  const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

  let stage = null;
  if (diffDays <= 0) stage = "expired";
  else if (diffDays === 3) stage = "3";
  else if (diffDays === 5) stage = "5";
  else return;

  const exists = await db.collection("alerts")
    .where("batchId", "==", batchId)
    .where("expiryStage", "==", stage)
    .get();

  if (!exists.empty) return;

  const productSnap = await db.collection("products").doc(batch.productId).get();
  const productData = productSnap.exists ? productSnap.data() : { productName: "Unknown", subCategory: "N/A" };

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
}

// --- BATCH CHANGE (Region: Singapore) ---
exports.onBatchChange = onDocumentWritten({
  document: "batches/{batchId}",
  region: "asia-southeast1"
}, async (event) => {
  const db = admin.firestore();
  const batch = event.data.after.data();
  if (!batch) return;
  await createAlertForBatch(db, batch, event.params.batchId);
});

// --- DAILY SCHEDULE (Region: Singapore) ---
exports.dailyExpiryCheck = onSchedule({
  schedule: "every day 00:00",
  timeZone: "Asia/Kuala_Lumpur",
  region: "asia-southeast1",
}, async () => {
  const db = admin.firestore();
  const snapshot = await db.collection("batches").get();
  for (const doc of snapshot.docs) {
    await createAlertForBatch(db, doc.data(), doc.id);
  }
});