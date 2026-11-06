
const express = require("express");
const mongoose = require("mongoose");

const authMiddleware = require("../middleware/authMiddleware");
const Task = require("../models/Task");
const User = require("../models/User");
const TaskShare = require("../models/TaskShare");
const { notifyUser } = require("../services/notificationService");
const { recordTaskActivity } = require("../services/activityService");

const router = express.Router();

router.use(authMiddleware);

const permissions = ["viewer", "editor"];

// GET: Lay danh sach nguoi duoc chia se cong viec
router.get("/:taskId/shares", async (req, res) => {
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
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    const shares = await TaskShare.find({ taskId })
      .populate("userId", "name email")
      .populate("sharedBy", "name email")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      shares,
    });
  } catch (error) {
    console.error("Get shares error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay danh sach chia se.",
    });
  }
});


// POST: Chia se cong viec cho mot nguoi
router.post("/:taskId/shares", async (req, res) => {
  try {
    const { taskId } = req.params;

    if (!mongoose.isValidObjectId(taskId)) {
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
        message: "Du lieu chia se khong hop le.",
      });
    }

    const { userId } = req.body;
    const permission = req.body.permission ?? "viewer";

    if (!mongoose.isValidObjectId(userId)) {
      return res.status(400).json({
        message: "ID nguoi dung khong hop le.",
      });
    }

    if (!permissions.includes(permission)) {
      return res.status(400).json({
        message: "Quyen chia se phai la viewer hoac editor.",
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

    if (String(userId) === String(req.user._id)) {
      return res.status(400).json({
        message: "Khong the chia se cong viec cho chinh minh.",
      });
    }

    const user = await User.findById(userId).select("_id");

    if (!user) {
      return res.status(404).json({
        message: "Tai khoan duoc chia se khong ton tai.",
      });
    }

    const existingShare = await TaskShare.findOne({
      taskId,
      userId,
    });

    const share = await TaskShare.findOneAndUpdate(
      { taskId, userId },
      {
        $set: {
          permission,
          sharedBy: req.user._id,
        },
      },
      {
        new: true,
        upsert: true,
        runValidators: true,
        setDefaultsOnInsert: true,
      }
    )
      .populate("userId", "name email")
      .populate("sharedBy", "name email");

          // Ghi lich su chia se hoac thay doi quyen
          if (!existingShare) {
            await recordTaskActivity({
              taskId: task._id,
              userId: req.user._id,
              action: "task_shared",
              details: {
                taskTitle: task.title,
                sharedUserId: String(userId),
                permission,
              },
            });
          } else if (existingShare.permission !== permission) {
            await recordTaskActivity({
              taskId: task._id,
              userId: req.user._id,
              action: "share_permission_changed",
              details: {
                taskTitle: task.title,
                sharedUserId: String(userId),
                previousPermission: existingShare.permission,
                newPermission: permission,
              },
            });
          }

    // Gui thong bao khi chia se moi hoac thay doi quyen
    if (!existingShare) {
      await notifyUser({
        recipientId: userId,
        actorId: req.user._id,
        taskId: task._id,
        type: "task_shared",
        title: "Ban duoc chia se cong viec",
        message: `${req.user.name} da chia se cong viec "${task.title}" voi ban. Quyen truy cap: ${permission}.`,
        metadata: {
          taskTitle: task.title,
          permission,
        },
        emailSubject: `Ban duoc chia se cong viec: ${task.title}`,
      });
    } else if (existingShare.permission !== permission) {
      await notifyUser({
        recipientId: userId,
        actorId: req.user._id,
        taskId: task._id,
        type: "task_shared",
        title: "Quyen truy cap cong viec da thay doi",
        message: `${req.user.name} da thay doi quyen truy cap cong viec "${task.title}" cua ban thanh ${permission}.`,
        metadata: {
          taskTitle: task.title,
          permission,
        },
        emailSubject: `Quyen truy cap da thay doi: ${task.title}`,
      });
    }

    return res.status(200).json({
      message: "Chia se cong viec thanh cong.",
      share,
    });
  } catch (error) {
    console.error("Create share error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi chia se cong viec.",
    });
  }
});


// PATCH: Thay doi quyen chia se
router.patch("/:taskId/shares/:shareId", async (req, res) => {
  try {
    const { taskId, shareId } = req.params;

    if (
      !mongoose.isValidObjectId(taskId) ||
      !mongoose.isValidObjectId(shareId)
    ) {
      return res.status(400).json({
        message: "ID cong viec hoac ID chia se khong hop le.",
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

    const { permission } = req.body;

    if (!permissions.includes(permission)) {
      return res.status(400).json({
        message: "Quyen chia se phai la viewer hoac editor.",
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

    const existingShare = await TaskShare.findOne({
      _id: shareId,
      taskId,
    });

    if (!existingShare) {
      return res.status(404).json({
        message: "Khong tim thay thong tin chia se.",
      });
    }

    const share = await TaskShare.findOneAndUpdate(
      {
        _id: shareId,
        taskId,
      },
      {
        $set: { permission },
      },
      {
        new: true,
        runValidators: true,
      }
    )
      .populate("userId", "name email")
      .populate("sharedBy", "name email");

          // Ghi lich su neu quyen truy cap thuc su thay doi
          if (existingShare.permission !== permission) {
            await recordTaskActivity({
              taskId: task._id,
              userId: req.user._id,
              action: "share_permission_changed",
              details: {
                taskTitle: task.title,
                sharedUserId: String(existingShare.userId),
                previousPermission: existingShare.permission,
                newPermission: permission,
              },
            });
          }

    // Gui thong bao neu quyen truy cap thuc su thay doi
    if (existingShare.permission !== permission) {
      await notifyUser({
        recipientId: existingShare.userId,
        actorId: req.user._id,
        taskId: task._id,
        type: "task_shared",
        title: "Quyen truy cap cong viec da thay doi",
        message: `${req.user.name} da thay doi quyen truy cap cong viec "${task.title}" cua ban thanh ${permission}.`,
        metadata: {
          taskTitle: task.title,
          permission,
        },
        emailSubject: `Quyen truy cap da thay doi: ${task.title}`,
      });
    }

    return res.status(200).json({
      message: "Cap nhat quyen chia se thanh cong.",
      share,
    });
  } catch (error) {
    console.error("Update share error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat quyen chia se.",
    });
  }
});


// DELETE: Thu hoi quyen chia se
router.delete("/:taskId/shares/:shareId", async (req, res) => {
  try {
    const { taskId, shareId } = req.params;

    if (
      !mongoose.isValidObjectId(taskId) ||
      !mongoose.isValidObjectId(shareId)
    ) {
      return res.status(400).json({
        message: "ID cong viec hoac ID chia se khong hop le.",
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

    const existingShare = await TaskShare.findOne({
      _id: shareId,
      taskId,
    });

    if (!existingShare) {
      return res.status(404).json({
        message: "Khong tim thay thong tin chia se.",
      });
    }

    await TaskShare.deleteOne({
      _id: shareId,
      taskId,
    });

        // Ghi lich su thu hoi quyen chia se
        await recordTaskActivity({
          taskId: task._id,
          userId: req.user._id,
          action: "share_revoked",
          details: {
            taskTitle: task.title,
            sharedUserId: String(existingShare.userId),
            previousPermission: existingShare.permission,
          },
        });

    // Thong bao cho nguoi bi thu hoi quyen chia se
    await notifyUser({
      recipientId: existingShare.userId,
      actorId: req.user._id,
      taskId: task._id,
      type: "task_shared",
      title: "Quyen truy cap cong viec da bi thu hoi",
      message: `${req.user.name} da thu hoi quyen truy cap cong viec "${task.title}" cua ban.`,
      metadata: {
        taskTitle: task.title,
        revoked: true,
      },
      emailSubject: `Quyen truy cap da bi thu hoi: ${task.title}`,
    });

    return res.status(200).json({
      message: "Thu hoi quyen chia se thanh cong.",
    });
  } catch (error) {
    console.error("Delete share error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi thu hoi quyen chia se.",
    });
  }
});


module.exports = router;
