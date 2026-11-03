
const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
require("dotenv").config();

const app = express();

// Middleware: xử lý CORS và dữ liệu JSON
app.use(cors());
app.use(express.json());

// Khai báo các API routes
app.use("/api/auth", require("./routes/auth"));
app.use("/api/tasks", require("./routes/tasks"));
app.use("/api/tasks", require("./routes/assignments"));
app.use("/api/tasks", require("./routes/shares"));
app.use("/api/users", require("./routes/users"));

// API kiểm tra server
app.get("/", (req, res) => {
  res.json({
    message: "Task Manager API is running",
  });
});

// API kiểm tra kết nối MongoDB
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    database:
      mongoose.connection.readyState === 1
        ? "connected"
        : "disconnected",
  });
});

const PORT = process.env.PORT || 3000;

async function startServer() {
  if (!process.env.MONGODB_URI) {
    console.error("Missing MONGODB_URI in .env");
    process.exit(1);
  }

  try {
    await mongoose.connect(process.env.MONGODB_URI);

    console.log("Connected to MongoDB Atlas successfully!");

    app.listen(PORT, () => {
      console.log(`Server running at http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error("MongoDB connection failed:", error.message);
    process.exit(1);
  }
}

startServer();
