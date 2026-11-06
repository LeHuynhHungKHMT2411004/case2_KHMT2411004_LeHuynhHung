
const express = require("express");
const mongoose = require("mongoose");
const Task = require("../models/Task");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");
const { notifyUser } = require("../services/notificationService");
const { recordTaskActivity } = require("../services/activityService");

const router = express.Router();

router.use(authMiddleware);

// GET: Lay danh sach nguoi duoc giao cong viec
router.get("/:taskId/assignees", async (req, res) => {
  try {
    const { taskId } = req.params;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.user._id,
    })
      .populate("assigneeIds", "name email")
      .populate("primaryAssigneeId", "name email");

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      assignees: task.assigneeIds,
      primaryAssignee: task.primaryAssigneeId,
    });
  } catch (error) {
    console.error("Get assignees error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay danh sach nguoi duoc giao.",
    });
  }
});

// PUT: Cap nhat danh sach nguoi duoc giao
router.put("/:taskId/assignees", async (req, res) => {
  try {
    const { taskId } = req.params;
    const { userIds, primaryAssigneeId } = req.body;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    if (!Array.isArray(userIds) || userIds.length > 50) {
      return res.status(400).json({
        message: "Danh sach nguoi duoc giao khong hop le.",
      });
    }

    if (!userIds.every((id) => mongoose.isValidObjectId(id))) {
      return res.status(400).json({
        message: "ID nguoi dung khong hop le.",
      });
    }

    // Loai bo ID trung lap
    const uniqueUserIds = [...new Set(userIds)];

    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Lưu danh sách người được giao trước khi cập nhật
    const oldAssigneeIds = task.assigneeIds.map((id) => String(id));
    const oldPrimaryAssigneeId = task.primaryAssigneeId
      ? String(task.primaryAssigneeId)
      : null;

    // Khong cho phep giao cong viec cho chinh nguoi tao
    if (uniqueUserIds.includes(String(req.user._id))) {
      return res.status(400).json({
        message: "Nguoi tao cong viec khong can tu giao cho chinh minh.",
      });
    }

    // Kiem tra tat ca tai khoan co ton tai
    const users = await User.find({
      _id: { $in: uniqueUserIds },
    }).select("_id");

    if (users.length !== uniqueUserIds.length) {
      return res.status(400).json({
        message: "Co tai khoan khong ton tai.",
      });
    }

    // Xac dinh nguoi phu trach chinh
    let selectedPrimaryId = null;

    if (Object.prototype.hasOwnProperty.call(req.body, "primaryAssigneeId")) {
      if (primaryAssigneeId !== null && primaryAssigneeId !== "") {
        if (!mongoose.isValidObjectId(primaryAssigneeId)) {
          return res.status(400).json({
            message: "ID nguoi phu trach chinh khong hop le.",
          });
        }

        if (!uniqueUserIds.includes(String(primaryAssigneeId))) {
          return res.status(400).json({
            message: "Nguoi phu trach chinh phai nam trong danh sach duoc giao.",
          });
        }

        selectedPrimaryId = primaryAssigneeId;
      }
    } else {
      const oldPrimaryId = task.primaryAssigneeId
        ? String(task.primaryAssigneeId)
        : null;

      selectedPrimaryId =
        oldPrimaryId && uniqueUserIds.includes(oldPrimaryId)
          ? oldPrimaryId
          : uniqueUserIds[0] || null;
    }

    task.assigneeIds = uniqueUserIds;
    task.primaryAssigneeId = selectedPrimaryId;

    await task.save();

        // Xac dinh nhung nguoi vua duoc giao moi
        const newlyAssignedIds = uniqueUserIds.filter(
          (id) => !oldAssigneeIds.includes(String(id))
        );

        // Xac dinh nhung nguoi bi go khoi cong viec
        const removedAssigneeIds = oldAssigneeIds.filter(
          (id) =>
            !uniqueUserIds.some((newId) => String(newId) === id)
        );

        // Xac dinh nguoi phu trach chinh moi
        const newPrimaryAssigneeId = selectedPrimaryId
          ? String(selectedPrimaryId)
          : null;

        // Kiem tra danh sach co thay doi thuc su hay khong
        const hasAssigneeChanges =
          newlyAssignedIds.length > 0 ||
          removedAssigneeIds.length > 0 ||
          oldPrimaryAssigneeId !== newPrimaryAssigneeId;

        // Ghi lich su neu co thay doi
        if (hasAssigneeChanges) {
          await recordTaskActivity({
            taskId: task._id,
            userId: req.user._id,
            action: "assignees_updated",
            details: {
              taskTitle: task.title,
              addedAssigneeIds: newlyAssignedIds.map((id) => String(id)),
              removedAssigneeIds,
              previousPrimaryAssigneeId: oldPrimaryAssigneeId,
              newPrimaryAssigneeId,
            },
          });
        }

    // Gửi thông báo cho từng người vừa được giao
    for (const userId of newlyAssignedIds) {
      await notifyUser({
        recipientId: userId,
        actorId: req.user._id,
        taskId: task._id,
        type: "task_assigned",
        title: "Bạn được giao công việc mới",
        message: `${req.user.name} đã giao cho bạn công việc "${task.title}".`,
        metadata: {
          taskTitle: task.title,
        },
        emailSubject: `Bạn được giao công việc: ${task.title}`,
      });
    }

    const updatedTask = await Task.findById(task._id)
      .populate("assigneeIds", "name email")
      .populate("primaryAssigneeId", "name email");

    return res.status(200).json({
      message: "Cap nhat danh sach nguoi duoc giao thanh cong.",
      assignees: updatedTask.assigneeIds,
      primaryAssignee: updatedTask.primaryAssigneeId,
    });
  } catch (error) {
    console.error("Update assignees error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat nguoi duoc giao.",
    });
  }
});

// DELETE: Xoa mot nguoi khoi danh sach duoc giao
router.delete("/:taskId/assignees/:userId", async (req, res) => {
  try {
    const { taskId, userId } = req.params;

    if (
      !mongoose.isValidObjectId(taskId) ||
      !mongoose.isValidObjectId(userId)
    ) {
      return res.status(400).json({
        message: "ID cong viec hoac ID nguoi dung khong hop le.",
      });
    }

    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    const isAssigned = task.assigneeIds.some(
      (id) => String(id) === userId
    );

    if (!isAssigned) {
      return res.status(404).json({
        message: "Nguoi dung khong nam trong danh sach duoc giao.",
      });
    }

    task.assigneeIds = task.assigneeIds.filter(
      (id) => String(id) !== userId
    );

        // Kiem tra nguoi bi xoa co phai nguoi phu trach chinh khong
        const wasPrimaryAssignee =
          task.primaryAssigneeId &&
          String(task.primaryAssigneeId) === userId;

        // Neu xoa nguoi phu trach chinh thi bo trong truong nay
        if (wasPrimaryAssignee) {
          task.primaryAssigneeId = null;
        }

        await task.save();

        // Ghi lich su xoa nguoi duoc giao
        await recordTaskActivity({
          taskId: task._id,
          userId: req.user._id,
          action: "assignee_removed",
          details: {
            taskTitle: task.title,
            removedAssigneeId: userId,
            wasPrimaryAssignee: Boolean(wasPrimaryAssignee),
          },
        });

    const updatedTask = await Task.findById(task._id)
      .populate("assigneeIds", "name email")
      .populate("primaryAssigneeId", "name email");

    return res.status(200).json({
      message: "Da xoa nguoi dung khoi danh sach duoc giao.",
      assignees: updatedTask.assigneeIds,
      primaryAssignee: updatedTask.primaryAssigneeId,
    });
  } catch (error) {
    console.error("Delete assignee error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi xoa nguoi duoc giao.",
    });
  }
});

module.exports = router;
