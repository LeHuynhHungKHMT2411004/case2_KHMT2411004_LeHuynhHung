const nodemailer = require("nodemailer");

const User = require("../models/User");
const Notification = require("../models/Notification");
const EmailLog = require("../models/EmailLog");

// Tạo kết nối SMTP để gửi email
function createTransporter() {
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;

  // Chưa cấu hình SMTP
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) {
    return null;
  }

  const port = Number(SMTP_PORT || 587);

  return nodemailer.createTransport({
    host: SMTP_HOST,
    port,
    secure: process.env.SMTP_SECURE === "true" || port === 465,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
  });
}

// Tạo thông báo trong ứng dụng và gửi email
async function notifyUser({
  recipientId,
  actorId = null,
  taskId = null,
  type,
  title,
  message,
  metadata = {},
  emailSubject = title,
  emailText,
}) {
  try {
    // Tìm tài khoản nhận thông báo
    const recipient = await User.findById(recipientId).select("name email");

    if (!recipient) {
      console.error("Notification recipient not found.");
      return null;
    }

    // Tạo thông báo trong ứng dụng
    const notification = await Notification.create({
      recipient: recipient._id,
      actor: actorId,
      task: taskId,
      type,
      title,
      message,
      metadata,
    });

    // Chuẩn bị nội dung email
    const subject = emailSubject || title;

    const text =
      emailText ||
      `Xin chào ${recipient.name},

${message}

Đây là email tự động từ hệ thống Task Manager.`;

    const transporter = createTransporter();

    let status = "failed";
    let errorMessage = "";
    let sentAt = null;

    // Kiểm tra cấu hình SMTP
    if (!transporter) {
      errorMessage =
        "Chưa cấu hình SMTP_HOST, SMTP_USER và SMTP_PASS trong file .env.";
    } else {
      try {
        // Gửi email
        await transporter.sendMail({
          from: process.env.SMTP_FROM || process.env.SMTP_USER,
          to: recipient.email,
          subject,
          text,
        });

        status = "sent";
        sentAt = new Date();
      } catch (emailError) {
        errorMessage = emailError.message || "Không thể gửi email.";
      }
    }

    // Lưu lịch sử gửi email
    await EmailLog.create({
      recipient: recipient._id,
      recipientEmail: recipient.email,
      task: taskId,
      notification: notification._id,
      type,
      subject,
      status,
      errorMessage,
      sentAt,
    });

    if (status === "failed") {
      console.error("Notification email failed:", errorMessage);
    }

    return notification;
  } catch (error) {
    console.error("Create notification error:", error.message);
    return null;
  }
}

module.exports = {
  notifyUser,
};