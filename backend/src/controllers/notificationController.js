const prisma = require("../lib/prisma");

exports.getNotifications = async (req, res) => {
    const userId = Number(req.params.userId);

    try {
        const notifications = await prisma.notification.findMany({
            where: { userId: userId },
            orderBy: { createdAt: "desc" },
        });

        return res.json({ notifications });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to fetch notifications" });
    }
};

exports.markAsRead = async (req, res) => {
    const notificationId = Number(req.params.id);

    try {
        await prisma.notification.update({
            where: { id: notificationId },
            data: { isRead: true },
        });

        return res.json({ message: "Notification marked as read" });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to update notification" });
    }
};
