const express = require("express");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Tat ca API user deu yeu cau dang nhap
router.use(authMiddleware);

// SEARCH: Tim kiem nguoi dung theo email
router.get("/search", async (req, res) => {
  try {
    const query =
      typeof req.query.q === "string"
        ? req.query.q.trim()
        : "";

    if (query.length < 2 || query.length > 100) {
      return res.status(400).json({
        message: "Tu khoa tim kiem phai tu 2 den 100 ky tu.",
      });
    }

    // Bao ve bieu thuc chinh quy
    const escapedQuery = query.replace(
      /[.*+?^${}()|[\]\\]/g,
      "\\$&"
    );

    // Tim tai khoan theo email, khong hien thi tai khoan hien tai
    const users = await User.find({
      _id: { $ne: req.user._id },
      email: {
        $regex: escapedQuery,
        $options: "i",
      },
    })
      .select("_id name email")
      .sort({ email: 1 })
      .limit(10);

    return res.status(200).json({
      count: users.length,
      users,
    });
  } catch (error) {
    console.error("Search users error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi tim kiem nguoi dung.",
    });
  }
});

module.exports = router;