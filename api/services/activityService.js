const TaskActivity = require("../models/TaskActivity");

// Ghi lai lich su hoat dong cua cong viec
async function recordTaskActivity({
  taskId,
  userId,
  action,
  details = {},
}) {
  try {
    await TaskActivity.create({
      taskId,
      userId,
      action,
      details,
    });
  } catch (error) {
    // Loi ghi lich su khong lam gian doan thao tac chinh
    console.error("Record task activity error:", error.message);
  }
}

module.exports = {
  recordTaskActivity,
};