
const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

function createToken(userId) {
  return jwt.sign(
    { userId: userId.toString() },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );
}

// Dang ky tai khoan
router.post("/register", async (req, res) => {
  try {
    const { name, email, password } = req.body;

    if (
      typeof name !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string" ||
      !name.trim() ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        message: "Vui long nhap day du thong tin.",
      });
    }

    if (password.length < 8) {
      return res.status(400).json({
        message: "Mat khau phai co it nhat 8 ky tu.",
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const existingUser = await User.findOne({
      email: normalizedEmail,
    });

    if (existingUser) {
      return res.status(409).json({
        message: "Email nay da duoc dang ky.",
      });
    }

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      passwordHash,
    });

    return res.status(201).json({
      message: "Dang ky thanh cong.",
      token: createToken(user._id),
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        message: "Email nay da duoc dang ky.",
      });
    }

    console.error("Register error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi dang ky.",
    });
  }
});

// Dang nhap
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (
      typeof email !== "string" ||
      typeof password !== "string" ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        message: "Vui long nhap email va mat khau.",
      });
    }

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    }).select("+passwordHash");

    if (!user) {
      return res.status(401).json({
        message: "Email hoac mat khau khong dung.",
      });
    }

    const isPasswordCorrect = await bcrypt.compare(
      password,
      user.passwordHash
    );

    if (!isPasswordCorrect) {
      return res.status(401).json({
        message: "Email hoac mat khau khong dung.",
      });
    }

    return res.status(200).json({
      message: "Dang nhap thanh cong.",
      token: createToken(user._id),
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (error) {
    console.error("Login error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi dang nhap.",
    });
  }
});


router.get("/me", authMiddleware, (req, res) => {
  return res.status(200).json({
    message: "Lay thong tin tai khoan thanh cong.",
    user: {
      id: req.user._id,
      name: req.user.name,
      email: req.user.email,
      createdAt: req.user.createdAt,
    },
  });
});

// Cap nhat thong tin ca nhan
router.put("/me", authMiddleware, async (req, res) => {
  try {
    const { name } = req.body;

    if (typeof name !== "string" || !name.trim()) {
      return res.status(400).json({
        message: "Ho ten khong duoc de trong.",
      });
    }

    if (name.trim().length > 100) {
      return res.status(400).json({
        message: "Ho ten toi da 100 ky tu.",
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: { name: name.trim() } },
      { new: true }
    );

    return res.status(200).json({
      message: "Cap nhat thong tin ca nhan thanh cong.",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error("Update profile error:", error.message);
    return res.status(500).json({
      message: "Loi may chu khi cap nhat thong tin.",
    });
  }
});

// Doi mat khau
router.put("/change-password", authMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (
      typeof currentPassword !== "string" ||
      typeof newPassword !== "string" ||
      !currentPassword ||
      !newPassword
    ) {
      return res.status(400).json({
        message: "Vui long nhap mat khau hien tai va mat khau moi.",
      });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({
        message: "Mat khau moi phai co it nhat 8 ky tu.",
      });
    }

    const user = await User.findById(req.user._id).select("+passwordHash");

    if (!user) {
      return res.status(404).json({
        message: "Khong tim thay tai khoan.",
      });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.passwordHash);

    if (!isMatch) {
      return res.status(400).json({
        message: "Mat khau hien tai khong dung.",
      });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();

    return res.status(200).json({
      message: "Doi mat khau thanh cong.",
    });
  } catch (error) {
    console.error("Change password error:", error.message);
    return res.status(500).json({
      message: "Loi may chu khi doi mat khau.",
    });
  }
});

module.exports = router;
