const express = require("express");
const Task = require("../models/Task");
const TaskShare = require("../models/TaskShare");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

router.use(authMiddleware);

// Lay cac cong viec ma nguoi dung co quyen truy cap
async function getAccessibleTaskFilter(userId) {
  const sharedTaskIds = await TaskShare.distinct("taskId", {
    userId,
  });

  return {
    $or: [
      { createdBy: userId },
      { assigneeIds: userId },
      { _id: { $in: sharedTaskIds } },
    ],
  };
}

// 1. GET /statistics/tasks
// Thong ke tong so cong viec theo trang thai
router.get("/tasks", async (req, res) => {
  try {
    const filter = await getAccessibleTaskFilter(req.user._id);

    const [total, results] = await Promise.all([
      Task.countDocuments(filter),
      Task.aggregate([
        { $match: filter },
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    const byStatus = {
      todo: 0,
      in_progress: 0,
      completed: 0,
    };

    results.forEach((item) => {
      byStatus[item._id] = item.count;
    });

    return res.status(200).json({
      total,
      byStatus,
    });
  } catch (error) {
    console.error("Task statistics error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi thong ke cong viec.",
    });
  }
});

// 2. GET /statistics/assignments
// Thong ke cong viec duoc giao va dang phu trach
router.get("/assignments", async (req, res) => {
  try {
    const userId = req.user._id;

    const [
      assignedToMe,
      primaryResponsible,
      assignedByMe,
    ] = await Promise.all([
      Task.countDocuments({
        assigneeIds: userId,
      }),

      Task.countDocuments({
        primaryAssigneeId: userId,
      }),

      Task.countDocuments({
        createdBy: userId,
        "assigneeIds.0": { $exists: true },
      }),
    ]);

    return res.status(200).json({
      assignedToMe,
      primaryResponsible,
      assignedByMe,
    });
  } catch (error) {
    console.error("Assignment statistics error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi thong ke giao viec.",
    });
  }
});

// 3. GET /statistics/deadlines
// Thong ke cong viec sap den han va qua han
router.get("/deadlines", async (req, res) => {
  try {
    const filter = await getAccessibleTaskFilter(req.user._id);

    const now = new Date();
    const sevenDaysLater = new Date(
      now.getTime() + 7 * 24 * 60 * 60 * 1000
    );

    const dueSoonFilter = {
      ...filter,
      status: { $ne: "completed" },
      dueDate: {
        $gte: now,
        $lte: sevenDaysLater,
      },
    };

    const overdueFilter = {
      ...filter,
      status: { $ne: "completed" },
      dueDate: { $lt: now },
    };

    const selectFields =
      "title status priority dueDate createdBy primaryAssigneeId";

    const [
      dueSoonCount,
      overdueCount,
      dueSoon,
      overdue,
    ] = await Promise.all([
      Task.countDocuments(dueSoonFilter),
      Task.countDocuments(overdueFilter),

      Task.find(dueSoonFilter)
        .select(selectFields)
        .populate("createdBy", "name email")
        .populate("primaryAssigneeId", "name email")
        .sort({ dueDate: 1 })
        .limit(20),

      Task.find(overdueFilter)
        .select(selectFields)
        .populate("createdBy", "name email")
        .populate("primaryAssigneeId", "name email")
        .sort({ dueDate: 1 })
        .limit(20),
    ]);

    return res.status(200).json({
      dueSoonCount,
      overdueCount,
      dueSoon,
      overdue,
      upcomingDays: 7,
    });
  } catch (error) {
    console.error("Deadline statistics error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi thong ke han cong viec.",
    });
  }
});

module.exports = router;
