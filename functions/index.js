const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

exports.sendQueuedPushNotification = onDocumentCreated(
  "push_queue/{jobId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const data = snapshot.data();
    const tokens = Array.isArray(data.tokens) ? data.tokens.filter(Boolean) : [];
    if (tokens.length === 0) {
      await snapshot.ref.set(
        {
          status: "skipped",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: "No tokens",
        },
        {merge: true},
      );
      return;
    }

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: data.title || "Campus Sync",
          body: data.body || "You have a new update.",
        },
        data: {
          postId: data.postId || "",
          type: data.type || "general",
          userId: data.userId || "",
        },
      });

      await snapshot.ref.set(
        {
          status: "sent",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          successCount: response.successCount,
          failureCount: response.failureCount,
        },
        {merge: true},
      );
    } catch (error) {
      await snapshot.ref.set(
        {
          status: "failed",
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: error.message,
        },
        {merge: true},
      );
    }
  },
);
