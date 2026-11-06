
const express = require("express");
const mongoose = require("mongoose");
const Task = require("../models/Task");
const TaskShare = require("../models/TaskShare");
const authMiddleware = require("../middleware/authMiddleware");
const { notifyUser } = require("../services/notificationService");
const TaskActivity = require("../models/TaskActivity");
const { recordTaskActivity } = require("../services/activityService");

const router = express.Router();

const statuses = ["todo", "in_progress", "completed"];
const priorities = ["low", "medium", "high"];

// Gui thong bao cho nhung nguoi lien quan den cong viec
async function notifyTaskParticipants(task, actorId, notificationData) {
  try {
    // Lay danh sach nguoi duoc chia se cong viec
    const shares = await TaskShare.find({
      taskId: task._id,
    }).select("userId");

    // Tao danh sach nguoi nhan, tu dong loai bo ID trung lap
    const recipientIds = new Set();

    // Them nguoi tao cong viec
    if (task.createdBy) {
      recipientIds.add(String(task.createdBy));
    }

    // Them nhung nguoi duoc giao cong viec
    for (const userId of task.assigneeIds || []) {
      recipientIds.add(String(userId));
    }

    // Them nhung nguoi duoc chia se cong viec
    for (const share of shares) {
      recipientIds.add(String(share.userId));
    }

    // Khong gui thong bao cho nguoi thuc hien thao tac
    recipientIds.delete(String(actorId));

    // Gui thong bao cho tung nguoi nhan
    for (const recipientId of recipientIds) {
      await notifyUser({
        recipientId,
        actorId,
        taskId: task._id,
        type: notificationData.type,
        title: notificationData.title,
        message: notificationData.message,
        metadata: notificationData.metadata,
        emailSubject: notificationData.emailSubject,
      });
    }
  } catch (error) {
    console.error("Notify task participants error:", error.message);
  }
}

// Kiem tra quyen truy cap cong viec cua nguoi dung
async function getTaskAccess(task, userId) {
  const currentUserId = String(userId);

  // Kiem tra nguoi tao cong viec
  const isCreator =
    String(task.createdBy) === currentUserId;

  // Kiem tra nguoi duoc giao cong viec
  const isAssignee = (task.assigneeIds || []).some(
    (id) => String(id) === currentUserId
  );

  // Tim quyen chia se neu khong phai nguoi tao
  const share = isCreator
    ? null
    : await TaskShare.findOne({
        taskId: task._id,
        userId: userId,
      });

  // Xac dinh quyen truy cap
  const canView =
    isCreator || isAssignee || Boolean(share);

  const canEditContent =
    isCreator || share?.permission === "editor";

  const canUpdateStatus =
    isCreator ||
    isAssignee ||
    share?.permission === "editor";

  return {
    isCreator,
    isAssignee,
    share,
    canView,
    canEditContent,
    canUpdateStatus,
  };
}

// Tat ca API task deu yeu cau dang nhap
router.use(authMiddleware);

// CREATE: Tao cong viec
router.post("/", async (req, res) => {
  try {
    const { title, description, status, priority, dueDate } = req.body;

    if (typeof title !== "string" || !title.trim()) {
      return res.status(400).json({
        message: "Ten cong viec khong duoc de trong.",
      });
    }

    if (title.trim().length > 200) {
      return res.status(400).json({
        message: "Ten cong viec toi da 200 ky tu.",
      });
    }

    if (
      status !== undefined &&
      !statuses.includes(status)
    ) {
      return res.status(400).json({
        message: "Trang thai khong hop le.",
      });
    }

    if (
      priority !== undefined &&
      !priorities.includes(priority)
    ) {
      return res.status(400).json({
        message: "Muc do uu tien khong hop le.",
      });
    }

    if (
      description !== undefined &&
      typeof description !== "string"
    ) {
      return res.status(400).json({
        message: "Mo ta phai la chuoi ky tu.",
      });
    }

    let parsedDueDate = null;

    if (dueDate !== undefined && dueDate !== null && dueDate !== "") {
      parsedDueDate = new Date(dueDate);

      if (Number.isNaN(parsedDueDate.getTime())) {
        return res.status(400).json({
          message: "Han hoan thanh khong hop le.",
        });
      }
    }

    const task = await Task.create({
      title: title.trim(),
      description: description ?? "",
      status: status ?? "todo",
      priority: priority ?? "medium",
      dueDate: parsedDueDate,
      createdBy: req.user._id,
    });

        // Ghi lai lich su tao cong viec
        await recordTaskActivity({
          taskId: task._id,
          userId: req.user._id,
          action: "task_created",
          details: {
            title: task.title,
            status: task.status,
            priority: task.priority,
            dueDate: task.dueDate,
          },
        });

    return res.status(201).json({
      message: "Tao cong viec thanh cong.",
      task,
    });
  } catch (error) {
    console.error("Create task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi tao cong viec.",
    });
  }
});

// READ ALL: Lay danh sach cong viec nguoi dung co quyen truy cap
router.get("/", async (req, res) => {
  try {
    // Tim cac cong viec duoc chia se cho nguoi dang nhap
    const userShares = await TaskShare.find({
      userId: req.user._id,
    }).select("taskId permission");

    const sharedTaskIds = userShares.map(
      (share) => share.taskId
    );

    // Lay cong viec do nguoi dung tao, duoc giao hoac duoc chia se
    const tasks = await Task.find({
      $or: [
        { createdBy: req.user._id },
        { assigneeIds: req.user._id },
        { _id: { $in: sharedTaskIds } },
      ],
    }).sort({ createdAt: -1 });

    // Bo sung thong tin quyen truy cap cho tung cong viec
    const tasksWithAccess = tasks.map((task) => {
      const taskObject = task.toObject();

      const isCreator =
        String(task.createdBy) === String(req.user._id);

      const isAssignee = (task.assigneeIds || []).some(
        (id) => String(id) === String(req.user._id)
      );

      const share = userShares.find(
        (item) => String(item.taskId) === String(task._id)
      );

      const sharePermission = share?.permission ?? null;

      return {
        ...taskObject,
        access: {
          isCreator,
          isAssignee,
          sharePermission,
          canView: true,
          canEditContent:
            isCreator || sharePermission === "editor",
          canUpdateStatus:
            isCreator ||
            isAssignee ||
            sharePermission === "editor",
          canDelete: isCreator,
        },
      };
    });

    return res.status(200).json({
      count: tasksWithAccess.length,
      tasks: tasksWithAccess,
    });
  } catch (error) {
    console.error("Get tasks error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay danh sach cong viec.",
    });
  }
});

// READ ACTIVITIES: Lay lich su hoat dong cua cong viec
router.get("/:id/activities", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    // Tim cong viec
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Kiem tra quyen xem cong viec
    const access = await getTaskAccess(task, req.user._id);

    if (!access.canView) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Lay toi da 100 hoat dong moi nhat
    const activities = await TaskActivity.find({
      taskId: task._id,
    })
      .populate("userId", "name email")
      .sort({ createdAt: -1 })
      .limit(100);

    return res.status(200).json({
      count: activities.length,
      activities,
    });
  } catch (error) {
    console.error("Get task activities error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay lich su hoat dong.",
    });
  }
});

// READ ONE: Lay chi tiet cong viec nguoi dung co quyen truy cap
router.get("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    // Tim cong viec theo ID
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Kiem tra quyen truy cap
    const access = await getTaskAccess(task, req.user._id);

    if (!access.canView) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Chuyen task sang object de bo sung thong tin quyen
    const taskObject = task.toObject();

    return res.status(200).json({
      task: {
        ...taskObject,
        access: {
          isCreator: access.isCreator,
          isAssignee: access.isAssignee,
          sharePermission: access.share?.permission ?? null,
          canView: access.canView,
          canEditContent: access.canEditContent,
          canUpdateStatus: access.canUpdateStatus,
          canDelete: access.isCreator,
        },
      },
    });
  } catch (error) {
    console.error("Get task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay cong viec.",
    });
  }
});

// UPDATE: Cap nhat cong viec theo quyen truy cap
router.patch("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    if (
      !req.body ||
      typeof req.body !== "object" ||
      Array.isArray(req.body)
    ) {
      return res.status(400).json({
        message: "Du lieu cap nhat khong hop le.",
      });
    }

    const body = req.body;

    // Chi cho phep cap nhat cac truong duoc quy dinh
    const allowedFields = [
      "title",
      "description",
      "status",
      "priority",
      "dueDate",
    ];

    const unknownFields = Object.keys(body).filter(
      (field) => !allowedFields.includes(field)
    );

    if (unknownFields.length > 0) {
      return res.status(400).json({
        message: "Co truong du lieu khong duoc phep cap nhat.",
      });
    }

    // Tim cong viec
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Kiem tra quyen cua nguoi dang dang nhap
    const access = await getTaskAccess(task, req.user._id);

    if (!access.canView) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Xac dinh cac truong duoc gui len
    const contentFields = [
      "title",
      "description",
      "priority",
      "dueDate",
    ];

    const hasContentFields = contentFields.some(
      (field) => Object.prototype.hasOwnProperty.call(body, field)
    );

    const hasStatusField =
      Object.prototype.hasOwnProperty.call(body, "status");

    // Nguoi khong co quyen sua noi dung khong duoc cap nhat cac truong nay
    if (hasContentFields && !access.canEditContent) {
      return res.status(403).json({
        message: "Ban khong co quyen sua noi dung cong viec.",
      });
    }

    // Nguoi khong co quyen cap nhat trang thai khong duoc sua trang thai
    if (hasStatusField && !access.canUpdateStatus) {
      return res.status(403).json({
        message: "Ban khong co quyen cap nhat trang thai cong viec.",
      });
    }

    const updates = {};

    // Kiem tra va cap nhat ten cong viec
    if ("title" in body) {
      if (
        typeof body.title !== "string" ||
        !body.title.trim() ||
        body.title.trim().length > 200
      ) {
        return res.status(400).json({
          message: "Ten cong viec khong hop le.",
        });
      }

      updates.title = body.title.trim();
    }

    // Kiem tra va cap nhat mo ta
    if ("description" in body) {
      if (
        typeof body.description !== "string" ||
        body.description.length > 5000
      ) {
        return res.status(400).json({
          message: "Mo ta khong hop le.",
        });
      }

      updates.description = body.description;
    }

    // Kiem tra va cap nhat trang thai
    if ("status" in body) {
      if (!statuses.includes(body.status)) {
        return res.status(400).json({
          message: "Trang thai khong hop le.",
        });
      }

      updates.status = body.status;
    }

    // Kiem tra va cap nhat muc do uu tien
    if ("priority" in body) {
      if (!priorities.includes(body.priority)) {
        return res.status(400).json({
          message: "Muc do uu tien khong hop le.",
        });
      }

      updates.priority = body.priority;
    }

    // Kiem tra va cap nhat han hoan thanh
    if ("dueDate" in body) {
      if (body.dueDate === null || body.dueDate === "") {
        updates.dueDate = null;
      } else {
        const date = new Date(body.dueDate);

        if (Number.isNaN(date.getTime())) {
          return res.status(400).json({
            message: "Han hoan thanh khong hop le.",
          });
        }

        updates.dueDate = date;
      }
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        message: "Khong co thong tin hop le de cap nhat.",
      });
    }

    // Luu lai trang thai cu truoc khi cap nhat
    const previousStatus = task.status;

    // Xac dinh nhung truong thuc su thay doi
    const changedFields = Object.keys(updates).filter((field) => {
      const oldValue = task[field];
      const newValue = updates[field];

      // So sanh ngay thang theo timestamp
      if (field === "dueDate") {
        const oldTime = oldValue
          ? new Date(oldValue).getTime()
          : null;

        const newTime = newValue
          ? new Date(newValue).getTime()
          : null;

        return oldTime !== newTime;
      }

      return oldValue !== newValue;
    });

        // Luu gia tri cu cua cac truong thay doi
        const previousValues = {};

        for (const field of changedFields) {
          previousValues[field] = task[field];
        }

    // Luu thay doi
    task.set(updates);
    await task.save();

    // Gui thong bao neu co thay doi thuc su
        if (changedFields.length > 0) {
          const isNewlyCompleted =
            previousStatus !== "completed" &&
            task.status === "completed";

          // Xac dinh loai hoat dong
          let activityAction = "task_updated";

          if (isNewlyCompleted) {
            activityAction = "task_completed";
          } else if (changedFields.includes("status")) {
            activityAction = "status_changed";
          }

          // Luu gia tri moi cua cac truong thay doi
          const newValues = {};

          for (const field of changedFields) {
            newValues[field] = task[field];
          }

          // Ghi lich su hoat dong
          await recordTaskActivity({
            taskId: task._id,
            userId: req.user._id,
            action: activityAction,
            details: {
              taskTitle: task.title,
              changedFields,
              previousValues,
              newValues,
            },
          });

          if (isNewlyCompleted) {
        // Thong bao khi cong viec duoc hoan thanh
        await notifyTaskParticipants(task, req.user._id, {
          type: "task_completed",
          title: "Cong viec da hoan thanh",
          message: `${req.user.name} da hoan thanh cong viec "${task.title}".`,
          metadata: {
            taskTitle: task.title,
            changedFields,
          },
          emailSubject: `Cong viec da hoan thanh: ${task.title}`,
        });
      } else {
        // Thong bao khi noi dung cong viec duoc cap nhat
        await notifyTaskParticipants(task, req.user._id, {
          type: "task_updated",
          title: "Cong viec da duoc cap nhat",
          message: `${req.user.name} da cap nhat cong viec "${task.title}".`,
          metadata: {
            taskTitle: task.title,
            changedFields,
          },
          emailSubject: `Cong viec da duoc cap nhat: ${task.title}`,
        });
      }
    }

    return res.status(200).json({
      message: "Cap nhat cong viec thanh cong.",
      task: {
        ...task.toObject(),
        access: {
          isCreator: access.isCreator,
          isAssignee: access.isAssignee,
          sharePermission: access.share?.permission ?? null,
          canView: access.canView,
          canEditContent: access.canEditContent,
          canUpdateStatus: access.canUpdateStatus,
          canDelete: access.isCreator,
        },
      },
    });
  } catch (error) {
    console.error("Update task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat cong viec.",
    });
  }
});

// DELETE: Xoa cong viec va cac quyen chia se lien quan
router.delete("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    // Chi nguoi tao moi co quyen xoa cong viec
    const task = await Task.findOne({
      _id: req.params.id,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Xoa cong viec
    await task.deleteOne();

    // Ghi lai lich su xoa cong viec
    await recordTaskActivity({
      taskId: task._id,
      userId: req.user._id,
      action: "task_deleted",
      details: {
        title: task.title,
      },
    });

    // Xoa tat ca quyen chia se cua cong viec
    const deletedShares = await TaskShare.deleteMany({
      taskId: task._id,
    });

    return res.status(200).json({
      message: "Xoa cong viec thanh cong.",
      deletedShares: deletedShares.deletedCount,
    });
  } catch (error) {
    console.error("Delete task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi xoa cong viec.",
    });
  }
});

module.exports = router;
