
const express = require("express");
const mongoose = require("mongoose");
const Task = require("../models/Task");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

const statuses = ["todo", "in_progress", "completed"];
const priorities = ["low", "medium", "high"];

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
router.get("/", async (req, res) => {
  try {
    const tasks = await Task.find({
      createdBy: req.user._id,
    }).sort({ createdAt: -1 });

    return res.status(200).json({
      count: tasks.length,
      tasks,
    });
  } catch (error) {
    console.error("Get tasks error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay danh sach cong viec.",
    });
  }
});

// READ ONE: Lay chi tiet mot cong viec
router.get("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findOne({
      _id: req.params.id,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({ task });
  } catch (error) {
    console.error("Get task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi lay cong viec.",
    });
  }
});

// UPDATE: Cap nhat cong viec
router.patch("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    if (!req.body || typeof req.body !== "object" || Array.isArray(req.body)) {
      return res.status(400).json({
        message: "Du lieu cap nhat khong hop le.",
      });
    }

    const updates = {};
    const body = req.body;

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

    if ("status" in body) {
      if (!statuses.includes(body.status)) {
        return res.status(400).json({
          message: "Trang thai khong hop le.",
        });
      }

      updates.status = body.status;
    }

    if ("priority" in body) {
      if (!priorities.includes(body.priority)) {
        return res.status(400).json({
          message: "Muc do uu tien khong hop le.",
        });
      }

      updates.priority = body.priority;
    }

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

    const task = await Task.findOneAndUpdate(
      {
        _id: req.params.id,
        createdBy: req.user._id,
      },
      updates,
      {
        new: true,
        runValidators: true,
      }
    );

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      message: "Cap nhat cong viec thanh cong.",
      task,
    });
  } catch (error) {
    console.error("Update task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi cap nhat cong viec.",
    });
  }
});

// DELETE: Xoa cong viec
router.delete("/:id", async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "ID cong viec khong hop le.",
      });
    }

    const task = await Task.findOneAndDelete({
      _id: req.params.id,
      createdBy: req.user._id,
    });

    if (!task) {
      return res.status(404).json({
        message: "Khong tim thay cong viec.",
      });
    }

    return res.status(200).json({
      message: "Xoa cong viec thanh cong.",
    });
  } catch (error) {
    console.error("Delete task error:", error.message);

    return res.status(500).json({
      message: "Loi may chu khi xoa cong viec.",
    });
  }
});

module.exports = router;
