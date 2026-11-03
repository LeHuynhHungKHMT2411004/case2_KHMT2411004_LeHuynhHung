
const express = require("express");
const mongoose = require("mongoose");
const Task = require("../models/Task");
const TaskShare = require("../models/TaskShare");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

const permissions = ["viewer", "editor"];

// Tat ca API chia se deu yeu cau dang nhap
router.use(authMiddleware);

// GET: Lay danh sach nguoi duoc chia se cong viec
router.get("/:taskId/shares", async (req, res) => {
  try {
    const { taskId } = req.params;

    if (!mongoose.isValidObjectId(taskId)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    // Chi nguoi tao cong viec duoc xem danh sach chia se
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
      count: shares.length,
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

    // Kiem tra quyen so huu cong viec
    const task = await Task.findOne({
      _id: taskId,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    // Khong cho phep chia se cho chinh nguoi tao
    if (String(userId) === String(req.user._id)) {
      return res.status(400).json({
        message: "Khong the chia se cong viec cho chinh minh.",
      });
    }

    // Kiem tra tai khoan duoc chia se co ton tai
    const user = await User.findById(userId).select("_id");

    if (!user) {
      return res.status(404).json({
        message: "Tai khoan duoc chia se khong ton tai.",
      });
    }

    // Neu da chia se truoc do thi cap nhat quyen
    // Neu chua thi tao ban ghi chia se moi
    const share = await TaskShare.findOneAndUpdate(
      {
        taskId,
        userId,
      },
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

    if (!share) {
      return res.status(404).json({
        message: "Khong tim thay thong tin chia se.",
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

    const share = await TaskShare.findOneAndDelete({
      _id: shareId,
      taskId,
    });

    if (!share) {
      return res.status(404).json({
        message: "Khong tim thay thong tin chia se.",
      });
    }

    return res.status(200).json({
      message: "Da thu hoi quyen chia se thanh cong.",
    });
  } catch (error) {
    console.error("Delete share error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi thu hoi quyen chia se.",
    });
  }
});

module.exports = router;
