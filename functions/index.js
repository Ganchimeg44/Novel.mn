const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

exports.redeemXpForDays = onCall(async (request) => {
  const auth = request.auth;

  if (!auth) {
    throw new HttpsError(
        "unauthenticated",
        "Нэвтэрсэн хэрэглэгч шаардлагатай.",
    );
  }

  const data = request.data || {};

  const entitlementType = String(
      data.entitlementType || "",
  ).toLowerCase();

  const days = Number(data.days);

  if (
    entitlementType !== "vip" &&
    entitlementType !== "vvip"
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Эрхийн төрөл VIP эсвэл VVIP байх ёстой.",
    );
  }

  if (
    !Number.isInteger(days) ||
    days <= 0
  ) {
    throw new HttpsError(
        "invalid-argument",
        "Хоногийн тоо буруу байна.",
    );
  }

  const xpCost = days * 10;

  const userRef = db
      .collection("users")
      .doc(auth.uid);

  const result = await db.runTransaction(
      async (transaction) => {
        const userSnapshot =
          await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "Хэрэглэгчийн мэдээлэл олдсонгүй.",
          );
        }

        const userData =
          userSnapshot.data() || {};

        const currentXp =
          Number(userData.xp || 0);

        if (currentXp < xpCost) {
          throw new HttpsError(
              "failed-precondition",
              `XP хүрэлцэхгүй байна. ${xpCost} XP шаардлагатай.`,
          );
        }

        const now =
          admin.firestore.Timestamp.now();

        const nowDate =
          now.toDate();

        let currentExpiresAt;

        if (entitlementType === "vip") {
          currentExpiresAt =
            userData.vipExpiresAt;
        } else {
          currentExpiresAt =
            userData.vvipExpiresAt;
        }

        let baseDate = nowDate;

        if (
          currentExpiresAt &&
          typeof currentExpiresAt.toDate ===
            "function"
        ) {
          const existingDate =
            currentExpiresAt.toDate();

          if (existingDate > nowDate) {
            baseDate = existingDate;
          }
        }

        const newExpiresAtDate =
          new Date(
              baseDate.getTime() +
              days * 24 * 60 * 60 * 1000,
          );

        const newExpiresAt =
          admin.firestore.Timestamp.fromDate(
              newExpiresAtDate,
          );

        const newXp =
          currentXp - xpCost;

        const updateData = {
          xp: newXp,
        };

        if (entitlementType === "vip") {
          updateData.vipExpiresAt =
            newExpiresAt;
        } else {
          updateData.vvipExpiresAt =
            newExpiresAt;
        }

        transaction.update(
            userRef,
            updateData,
        );

        return {
          entitlementType,
          days,
          xpSpent: xpCost,
          remainingXp: newXp,
          expiresAt:
            newExpiresAtDate.toISOString(),
        };
      },
  );

  return {
    success: true,
    ...result,
  };
});

// ============================================================
// NEW CHAPTER PUBLISHED -> LIKED USERS NOTIFICATION
// ============================================================

const {
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

exports.notifyLikedUsersOnChapterPublished =
  onDocumentUpdated(
      "novels/{novelId}/translationDrafts/{draftId}",
      async (event) => {
        const before = event.data.before.data() || {};
        const after = event.data.after.data() || {};

        // Зөвхөн published рүү ШИНЭЭР шилжсэн үед ажиллана.
        if (
          before.status === "published" ||
          after.status !== "published"
        ) {
          return;
        }

        const novelId = event.params.novelId;

        const chapterId = String(
            after.chapterId || "",
        ).trim();

        const chapterTitle = String(
            after.title || "",
        ).trim();

        if (!novelId || !chapterId) {
          console.error(
              "Notification: novelId/chapterId missing",
              {
                novelId,
                chapterId,
                draftId: event.params.draftId,
              },
          );
          return;
        }

        // ----------------------------------------------------
        // Novel нэр
        // ----------------------------------------------------

        const novelSnapshot = await db
            .collection("novels")
            .doc(novelId)
            .get();

        const novelData = novelSnapshot.data() || {};

        const novelTitle = String(
            novelData.title || "Novel.mn",
        ).trim();

        // ----------------------------------------------------
        // Энэ зохиолыг liked хийсэн хэрэглэгчид
        // ----------------------------------------------------

        const usersSnapshot = await db
            .collection("users")
            .where(
                "likedNovelIds",
                "array-contains",
                novelId,
            )
            .get();

        if (usersSnapshot.empty) {
          console.log(
              `Notification: no liked users for ${novelId}`,
          );
          return;
        }

        const notificationTitle =
          "Шинэ бүлэг нийтлэгдлээ";

        const notificationBody =
          chapterTitle ?
            `${novelTitle} — ${chapterTitle}` :
            novelTitle;

        let sentCount = 0;

        // ----------------------------------------------------
        // User бүрийн FCM token-ууд руу илгээнэ.
        // ----------------------------------------------------

        for (const userDoc of usersSnapshot.docs) {
          const userData = userDoc.data() || {};

          const rawTokens = Array.isArray(
              userData.fcmTokens,
          ) ?
            userData.fcmTokens :
            [];

          const tokens = [
            ...new Set(
                rawTokens
                    .map((token) => String(token).trim())
                    .filter(Boolean),
            ),
          ];

          if (tokens.length === 0) {
            continue;
          }

          // FCM multicast нэг хүсэлтэд 500 хүртэл token.
          for (
            let index = 0;
            index < tokens.length;
            index += 500
          ) {
            const chunk = tokens.slice(
                index,
                index + 500,
            );

            const response =
              await admin.messaging()
                  .sendEachForMulticast({
                    tokens: chunk,
                    notification: {
                      title: notificationTitle,
                      body: notificationBody,
                    },
                    data: {
                      type: "chapter_published",
                      novelId,
                      chapterId,
                    },
                    webpush: {
                      fcmOptions: {
                        link: "/",
                      },
                    },
                  });

            sentCount += response.successCount;

            // Хүчингүй болсон token-уудыг цэвэрлэнэ.
            const invalidTokens = [];

            response.responses.forEach(
                (result, responseIndex) => {
                  if (result.success) {
                    return;
                  }

                  const code =
                    result.error &&
                    result.error.code;

                  if (
                    code ===
                      "messaging/registration-token-not-registered" ||
                    code ===
                      "messaging/invalid-registration-token"
                  ) {
                    invalidTokens.push(
                        chunk[responseIndex],
                    );
                  } else {
                    console.error(
                        "FCM send error:",
                        code,
                        result.error &&
                          result.error.message,
                    );
                  }
                },
            );

            if (invalidTokens.length > 0) {
              await userDoc.ref.update({
                fcmTokens:
                  admin.firestore.FieldValue.arrayRemove(
                      ...invalidTokens,
                  ),
              });
            }
          }
        }

        console.log(
            `Notification sent: novel=${novelId}, ` +
            `chapter=${chapterId}, success=${sentCount}`,
        );
      },
  );
