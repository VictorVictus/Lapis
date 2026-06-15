import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

const db = admin.firestore();

/**
 * Triggered when a new task is created in a group.
 * Sends FCM push notifications to all other group members.
 */
export const onGroupTaskCreate = functions.firestore
  .document('groups/{groupId}/tasks/{taskId}')
  .onCreate(async (snap, context) => {
    const { groupId } = context.params;
    const task = snap.data();

    // 1. Get group name
    const groupDoc = await db.collection('groups').doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? 'Group';

    // 2. Get all member IDs (exclude the creator)
    const membersSnap = await db
      .collection(`groups/${groupId}/members`)
      .get();
    const memberIds = membersSnap.docs
      .map((d) => d.id)
      .filter((id) => id !== (task.createdBy as string | undefined));

    // 3. Collect FCM tokens from all other members
    const tokens: string[] = [];
    for (const uid of memberIds) {
      const userDoc = await db.collection('users').doc(uid).get();
      const userTokens = userDoc.data()?.fcmTokens as string[] | undefined;
      if (userTokens) {
        tokens.push(...userTokens);
      }
    }
    if (tokens.length === 0) {
      functions.logger.log('No FCM tokens to notify for group task');
      return;
    }

    // 4. Send multicast notification
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: `New task in ${groupName}`,
        body: (task.title as string) ?? '',
      },
      android: {
        notification: {
          channelId: 'group_tasks',
          priority: 'high',
        },
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      functions.logger.log(
        `Group task notification sent to ${memberIds.length} members: ${response.successCount} success, ${response.failureCount} failures`,
      );

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (
            resp.error?.code === 'messaging/invalid-registration-token' ||
            resp.error?.code === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(tokens[idx]);
          }
        });
        if (invalidTokens.length > 0) {
          // Remove invalid tokens from each affected user's doc
          for (const uid of memberIds) {
            const userDoc = await db.collection('users').doc(uid).get();
            const userTokens = userDoc.data()?.fcmTokens as string[] | undefined;
            if (userTokens) {
              const toRemove = userTokens.filter((t) => invalidTokens.includes(t));
              if (toRemove.length > 0) {
                await userDoc.ref.update({
                  fcmTokens: admin.firestore.FieldValue.arrayRemove(toRemove),
                });
              }
            }
          }
        }
      }
    } catch (e) {
      functions.logger.error('Error sending group task notification:', e);
    }
  });

/**
 * Scheduled function that runs every 15 minutes.
 * Checks for tasks with deadlines approaching within the next hour
 * and sends FCM push notifications to the task owner.
 */
export const checkDeadlineReminders = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const inOneHour = new admin.firestore.Timestamp(
      now.seconds + 3600,
      now.nanoseconds,
    );

    const tasksSnapshot = await db
      .collection('tasks')
      .where('deadline', '>=', now)
      .where('deadline', '<=', inOneHour)
      .where('status', '==', 0) // TaskStatus.undone
      .get();

    if (tasksSnapshot.empty) {
      functions.logger.log('No upcoming deadline tasks found');
      return;
    }

    const userIds = new Set<string>();
    tasksSnapshot.docs.forEach((doc) => {
      userIds.add(doc.data().userId as string);
    });

    for (const userId of userIds) {
      const userDoc = await db.collection('users').doc(userId).get();
      const fcmTokens = userDoc.data()?.fcmTokens as string[] | undefined;
      if (!fcmTokens || fcmTokens.length === 0) continue;

      const userTasks = tasksSnapshot.docs.filter(
        (doc) => doc.data().userId === userId,
      );

      const title =
        userTasks.length === 1
          ? `"${userTasks[0].data().title}" deadline approaching`
          : `${userTasks.length} tasks are due soon`;

      const message: admin.messaging.MulticastMessage = {
        tokens: fcmTokens,
        notification: {
          title: 'Deadline Reminder',
          body: title,
        },
        android: {
          notification: {
            channelId: 'task_reminders',
            priority: 'high',
          },
        },
      };

      try {
        const response = await admin.messaging().sendEachForMulticast(message);
        functions.logger.log(
          `Sent reminders to ${userId}: ${response.successCount} success, ${response.failureCount} failures`,
        );

        // Clean up invalid tokens
        if (response.failureCount > 0) {
          const invalidTokens: string[] = [];
          response.responses.forEach((resp, idx) => {
            if (
              resp.error?.code === 'messaging/invalid-registration-token' ||
              resp.error?.code === 'messaging/registration-token-not-registered'
            ) {
              invalidTokens.push(fcmTokens[idx]);
            }
          });
          if (invalidTokens.length > 0) {
            await userDoc.ref.update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(invalidTokens),
            });
          }
        }
      } catch (e) {
        functions.logger.error(`Error sending to ${userId}:`, e);
      }
    }
  });
