const express = require("express");
const mongoose = require("mongoose");
const Notification = require("../models/Notification");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Tất cả API thông báo đều yêu cầu đăng nhập
router.use(authMiddleware);

// GET: Lấy danh sách thông báo
router.get("/", async (req, res) => {
  try {
    const notifications = await Notification.find({
      recipient: req.user._id,
    })
      .populate("actor", "name")
      .populate("task", "title status dueDate")
      .sort({ createdAt: -1 })
      .limit(50);

    const unreadCount = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false,
    });

    return res.status(200).json({
      count: notifications.length,
      unreadCount,
      notifications,
    });
  } catch (error) {
    console.error("Get notifications error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay danh sach thong bao.",
    });
  }
});

// GET: Lấy số lượng thông báo chưa đọc
router.get("/unread-count", async (req, res) => {
  try {
    const unreadCount = await Notification.countDocuments({
      recipient: req.user._id,
      isRead: false,
    });

    return res.status(200).json({
      unreadCount,
    });
  } catch (error) {
    console.error("Get unread count error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay so luong thong bao chua doc.",
    });
  }
});

// PATCH: Đánh dấu một thông báo đã đọc
router.patch("/:id/read", async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.isValidObjectId(id)) {
      return res.status(400).json({
        message: "ID thong bao khong hop le.",
      });
    }

    const notification = await Notification.findOneAndUpdate(
      {
        _id: id,
        recipient: req.user._id,
      },
      {
        $set: {
          isRead: true,
          readAt: new Date(),
        },
      },
      {
        new: true,
      }
    );

    if (!notification) {
      return res.status(404).json({
        message: "Khong tim thay thong bao.",
      });
    }

    return res.status(200).json({
      message: "Da danh dau thong bao la da doc.",
      notification,
    });
  } catch (error) {
    console.error("Mark notification read error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat thong bao.",
    });
  }
});

// PATCH: Đánh dấu tất cả thông báo đã đọc
router.patch("/read-all", async (req, res) => {
  try {
    const result = await Notification.updateMany(
      {
        recipient: req.user._id,
        isRead: false,
      },
      {
        $set: {
          isRead: true,
          readAt: new Date(),
        },
      }
    );

    return res.status(200).json({
      message: "Da danh dau tat ca thong bao la da doc.",
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error("Mark all notifications read error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat thong bao.",
    });
  }
});

module.exports = router;