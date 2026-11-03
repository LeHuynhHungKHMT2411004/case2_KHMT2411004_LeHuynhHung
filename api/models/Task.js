
const mongoose = require("mongoose");

const taskSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },

    description: {
      type: String,
      default: "",
      trim: true,
      maxlength: 5000,
    },

    status: {
      type: String,
      enum: ["todo", "in_progress", "completed"],
      default: "todo",
    },

    priority: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
    },

    dueDate: {
      type: Date,
      default: null,
    },

        // Danh sach nguoi duoc giao cong viec
        assigneeIds: {
          type: [
            {
              type: mongoose.Schema.Types.ObjectId,
              ref: "User",
            },
          ],
          default: [],
        },

        // Nguoi phu trach chinh
        primaryAssigneeId: {
          type: mongoose.Schema.Types.ObjectId,
          ref: "User",
          default: null,
        },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Task", taskSchema);
