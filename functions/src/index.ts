// functions/src/index.ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage();

// Definisikan tipe data (payload) yang diharapkan dari Flutter
interface DeleteUserData {
    userIdToDelete: string; // ID Dokumen Firestore (doc.id) pengguna yang akan dihapus
    adminUid?: string; // UID admin yang melakukan aksi (opsional untuk logging/sekuriti)
}

/**
 * Fungsi ini memadamkan rekod pengguna dari Firebase Authentication,
 * dokumen dari Firestore (koleksi 'users'), dan fail profil dari Storage.
 */
exports.deleteUserAndData = functions.https.onCall(async (request: functions.https.CallableRequest<DeleteUserData>) => {

    // 1. Sekuriti: Pastikan pemanggil (admin) disahkan
    if (!request.auth || !request.auth.uid) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to call this function.");
    }

    const userIdToDelete = request.data.userIdToDelete;

    if (!userIdToDelete) {
        throw new functions.https.HttpsError("invalid-argument", "The userIdToDelete parameter is required.");
    }

    let uid: string | undefined;
    let profilePictureUrl: string | undefined;

    try {
        // A. Ambil Dokumen Firestore untuk mendapatkan UID dan PP URL
        const userDoc = await db.collection("users").doc(userIdToDelete).get();

        if (!userDoc.exists) {
            return { status: "error", message: "User document not found in Firestore." };
        }

        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const userData = userDoc.data()!;
        uid = userData.uid;
        profilePictureUrl = userData.profilePictureUrl;

        // B. Operasi Delete di Storage (Jika ada Gambar Profil)
        if (profilePictureUrl) {
            const bucket = storage.bucket();
            const pathMatch = profilePictureUrl.match(/\/o\/(.+?)\?/);

            if (pathMatch && pathMatch[1]) {
                const filePath = decodeURIComponent(pathMatch[1]);
                await bucket.file(filePath).delete().catch(err => {
                    // Tangani jika file sudah tidak ada
                    if (err.code !== 404) throw err;
                    console.log(`Storage file for user ${uid} not found or already deleted.`);
                });
                console.log("Deleted profile picture from Storage.");
            }
        }

        // C. Operasi Delete di Firestore Database
        await db.collection("users").doc(userIdToDelete).delete();
        console.log(`Deleted user document from Firestore: ${userIdToDelete}`);

        // D. Operasi Delete di Firebase Authentication
        if (uid) {
            // Indentasi dibetulkan ke 12 ruang
            await auth.deleteUser(uid);
            console.log(`Deleted user from Auth: ${uid}`);
        } else {
            console.log("Warning: UID not found in Firestore document, Auth user skip deletion.");
        }

        return { status: "success", message: "User and associated data deleted successfully." };

    } catch (error) {
        console.error("Error performing deep deletion:", error);

        const errorMessage = (error instanceof Error) ? error.message : "An unknown error occurred.";

        return { status: "error", message: `Deep deletion failed. Details: ${errorMessage}` };
    }
});
