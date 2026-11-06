
const cron = require("node-cron");

const Task = require("../models/Task");
const TaskShare = require("../models/TaskShare");
const Notification = require("../models/Notification");
const { notifyUser } = require("./notificationService");

let isCheckingReminders = false;

// Kiểm tra các công việc sắp đến hạn
async function checkDueReminders() {
  // Tránh hai lần kiểm tra chạy chồng lên nhau
  if (isCheckingReminders) return;

  isCheckingReminders = true;

  try {
    const now = new Date();

    // Thời điểm sau 24 giờ
    const next24Hours = new Date(
      now.getTime() + 24 * 60 * 60 * 1000
    );

    // Lấy công việc chưa hoàn thành, có hạn trong 24 giờ tới
    const tasks = await Task.find({
      status: { $ne: "completed" },
      dueDate: {
        $gt: now,
        $lte: next24Hours,
      },
    })
      .select("title dueDate createdBy assigneeIds")
      .lean();

    for (const task of tasks) {
      // Lấy những người được chia sẻ công việc
      const sharedUsers = await TaskShare.find({
        taskId: task._id,
      })
        .select("userId")
        .lean();

      // Danh sách người nhận:
      // Người tạo + người được giao + người được chia sẻ
      const recipientIds = new Set(
        [
          task.createdBy,
          ...(task.assigneeIds || []),
          ...sharedUsers.map((share) => share.userId),
        ]
          .filter(Boolean)
          .map((id) => id.toString())
      );

      const dueDateKey = new Date(task.dueDate).toISOString();

      const dueDateText = new Date(task.dueDate).toLocaleString(
        "vi-VN",
        {
          timeZone: "Asia/Ho_Chi_Minh",
        }
      );

      for (const recipientId of recipientIds) {
        // Kiểm tra người này đã nhận nhắc hạn
        // cho đúng thời hạn của công việc này chưa
        const alreadyNotified = await Notification.exists({
          recipient: recipientId,
          task: task._id,
          type: "task_due_reminder",
          "metadata.dueDate": dueDateKey,
        });

        // Đã nhận rồi thì bỏ qua, không gửi trùng
        if (alreadyNotified) continue;

        const message =
          `Công việc "${task.title}" sẽ đến hạn vào ${dueDateText}.`;

        // Tạo thông báo trong ứng dụng và gửi email
        await notifyUser({
          recipientId,
          type: "task_due_reminder",
          taskId: task._id,
          title: "Nhắc nhở công việc sắp đến hạn",
          message,
          metadata: {
            dueDate: dueDateKey,
          },
          emailSubject: `Nhắc hạn công việc: ${task.title}`,
          emailText:
            `Xin chào,\n\n${message}\n\n` +
            "Vui lòng hoàn thành công việc trước thời hạn.\n\n" +
            "Đây là email tự động từ hệ thống Task Manager.",
        });
      }
    }

    console.log(
      `Đã kiểm tra nhắc hạn. Tìm thấy ${tasks.length} công việc trong 24 giờ tới.`
    );
  } catch (error) {
    console.error("Due reminder check failed:", error.message);
  } finally {
    isCheckingReminders = false;
  }
}

// Khởi động lịch kiểm tra tự động
function startReminderScheduler() {
  // Kiểm tra ngay khi server khởi động
  checkDueReminders();

  // Sau đó kiểm tra định kỳ mỗi 5 phút
  cron.schedule(
    "*/5 * * * *",
    () => {
      checkDueReminders();
    },
    {
      timezone: "Asia/Ho_Chi_Minh",
    }
  );

  console.log("Reminder scheduler started. Checking every 5 minutes.");
}

module.exports = {
  startReminderScheduler,
  checkDueReminders,
};
