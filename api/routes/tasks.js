
const express = require("express");
const mongoose = require("mongoose");
const Task = require("../models/Task");
const TaskShare = require("../models/TaskShare");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

const statuses = ["todo", "in_progress", "completed"];
const priorities = ["low", "medium", "high"];

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

// READ ALL: Lay danh sach cong viec cua nguoi dang nhap
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

// READ ONE: Lay chi tiet mot cong viec
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

    // Luu thay doi
    task.set(updates);
    await task.save();

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
// DELETE: Xoa cong viec
// DELETE: Xoa cong viec va cac quyen chia se lien quan
router.delete("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    // Chi nguoi tao moi co quyen xoa cong viec
    const task = await Task.findOneAndDelete({
      _id: req.params.id,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

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
