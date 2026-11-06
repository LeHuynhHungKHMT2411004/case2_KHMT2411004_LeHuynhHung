const mongoose = require("mongoose");

const emailLogSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },

    recipientEmail: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },

    task: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Task",
      default: null,
    },

    notification: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Notification",
      default: null,
    },

    type: {
      type: String,
      enum: [
        "task_assigned",
        "task_shared",
        "task_updated",
        "task_completed",
        "task_due_reminder",
      ],
      required: true,
    },

    subject: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },

    status: {
      type: String,
      enum: ["sent", "failed"],
      required: true,
    },

    errorMessage: {
      type: String,
      default: "",
      trim: true,
    },

    sentAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

emailLogSchema.index({ recipientEmail: 1, createdAt: -1 });
emailLogSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model("EmailLog", emailLogSchema);