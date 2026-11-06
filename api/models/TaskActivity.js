
const mongoose = require("mongoose");

const taskActivitySchema = new mongoose.Schema(
  {
    // Cong viec lien quan den hoat dong
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      required: true,
    },

    // Nguoi thuc hien hoat dong
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // Loai hoat dong
    action: {
      type: String,
      required: true,
      enum: [
        "task_created",
        "task_updated",
        "status_changed",
        "task_completed",
        "assignees_updated",
        "assignee_removed",
        "task_shared",
        "share_permission_changed",
        "share_revoked",
        "task_deleted",
      ],
    },

    // Thong tin chi tiet cua hoat dong
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: () => ({}),
    },
  },
  {
    timestamps: {
      createdAt: true,
      updatedAt: false,
    },
  }
);

// Ho tro lay lich su theo cong viec, moi nhat truoc
taskActivitySchema.index({
  taskId: 1,
  createdAt: -1,
});

// Ho tro lay lich su theo nguoi thuc hien
taskActivitySchema.index({
  userId: 1,
  createdAt: -1,
});

module.exports = mongoose.model(
  "TaskActivity",
  taskActivitySchema
);
