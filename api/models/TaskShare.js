const mongoose = require("mongoose");

const taskShareSchema = new mongoose.Schema(
  {
    // Cong viec duoc chia se
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      required: true,
    },

    // Nguoi duoc chia se
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // Quyen truy cap: viewer hoac editor
    permission: {
      type: String,
      enum: ["viewer", "editor"],
      default: "viewer",
      required: true,
    },

    // Nguoi thuc hien chia se
    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Moi nguoi chi co mot ban ghi chia se cho mot cong viec
taskShareSchema.index(
  { taskId: 1, userId: 1 },
  { unique: true }
);

module.exports = mongoose.model("TaskShare", taskShareSchema);