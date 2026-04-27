const prisma = require("../lib/prisma");

// Helper to create notifications
const createNotification = async (userId, title, message, type = "INFO") => {
    try {
        await prisma.notification.create({
            data: {
                userId: Number(userId),
                title,
                message,
                type
            }
        });
    } catch (err) {
        console.error("Failed to create notification:", err);
    }
};

// Existing fileComplaint method (keep as is)
exports.fileComplaint = async (req, res) => {
    const { driverId, passengerId, rideId, description, severity } = req.body;

    if (!driverId || !passengerId || !rideId || !description) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    try {
        const complaint = await prisma.complaint.create({
            data: {
                driverId: Number(driverId),
                passengerId: Number(passengerId),
                complainantId: Number(driverId),
                rideId: Number(rideId),
                title: `Complaint against passenger`,
                description: description,
                severity: severity || "MEDIUM",
                type: "DRIVER_COMPLAINT",
                status: "PENDING",
            },
            include: {
                driver: { select: { name: true, email: true } },
                passenger: { select: { name: true, email: true } },
                ride: { select: { origin: true, destination: true, departureTime: true } },
            },
        });

        // Notify the complainant driver
        await createNotification(
            driverId,
            "Complaint Filed",
            `Your complaint against the passenger has been filed successfully and is pending review.`,
            "SUCCESS"
        );

        // Notify the accused passenger
        await createNotification(
            passengerId,
            "Complaint Filed Against You",
            `A driver has filed a complaint against you. Admin will review it.`,
            "WARNING"
        );

        return res.status(201).json({
            message: "Complaint filed successfully",
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
};

// Existing getComplaints method (keep as is)
exports.getComplaints = async (req, res) => {
    const { status, type, driverId, passengerId } = req.query;

    try {
        const where = {};
        if (status) where.status = status;
        if (type) where.type = type;
        if (driverId) where.driverId = Number(driverId);
        if (passengerId) where.passengerId = Number(passengerId);

        const complaints = await prisma.complaint.findMany({
            where,
            include: {
                driver: { select: { id: true, name: true, email: true, phone: true } },
                passenger: { select: { id: true, name: true, email: true, phone: true, warningCount: true, isBanned: true } },
                ride: { select: { id: true, origin: true, destination: true, departureTime: true } },
            },
            orderBy: { createdAt: "desc" },
        });

        return res.json({ complaints });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
};

// Existing getComplaintById (keep as is)
exports.getComplaintById = async (req, res) => {
    const complaintId = Number(req.params.id);

    try {
        const complaint = await prisma.complaint.findUnique({
            where: { id: complaintId },
            include: {
                driver: { select: { id: true, name: true, email: true, phone: true } },
                passenger: { select: { id: true, name: true, email: true, phone: true, warningCount: true, isBanned: true } },
                ride: { select: { id: true, origin: true, destination: true, departureTime: true } },
            },
        });

        if (!complaint) {
            return res.status(404).json({ error: "Complaint not found" });
        }

        return res.json({ complaint });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
};

// Existing updateComplaintStatus (keep as is)
exports.updateComplaintStatus = async (req, res) => {
    const complaintId = Number(req.params.id);
    const { status } = req.body;

    const validStatuses = ["PENDING", "REVIEWED", "RESOLVED", "DISMISSED"];
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ error: "Invalid status" });
    }

    try {
        const complaint = await prisma.complaint.update({
            where: { id: complaintId },
            data: {
                status: status,
                updatedAt: new Date(),
            },
            include: {
                driver: { select: { id: true, name: true, email: true } },
                passenger: { select: { id: true, name: true, email: true } },
                complainant: { select: { id: true, name: true } },
            },
        });

        // Notify Complainant
        if (complaint.complainant) {
            await createNotification(
                complaint.complainant.id,
                "Complaint Update",
                `Your complaint #${complaintId} has been marked as ${status.toLowerCase()}.`,
                status === "RESOLVED" ? "SUCCESS" : "INFO"
            );
        }

        // Notify Accused Party
        let accusedId = null;
        if (complaint.type === "DRIVER_COMPLAINT" || complaint.type === "PASSENGER_TO_PASSENGER") {
            accusedId = complaint.passengerId;
        } else if (complaint.type === "PASSENGER_TO_DRIVER") {
            accusedId = complaint.driverId;
        }

        if (accusedId) {
            await createNotification(
                accusedId,
                "Complaint Update",
                `The complaint filed against you (#${complaintId}) is now ${status.toLowerCase()}.`,
                status === "DISMISSED" ? "SUCCESS" : "INFO"
            );
        }

        return res.json({
            message: `Complaint ${status.toLowerCase()} successfully`,
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
};

// NEW METHOD: Send warning to passenger
exports.sendWarning = async (req, res) => {
    const { complaintId, userId, message } = req.body; // Changed passengerId to userId

    // Extract adminId from Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: "Unauthorized" });
    }
    const adminId = authHeader.split(' ')[1];

    try {
        // Create warning record
        const warning = await prisma.warning.create({
            data: {
                userId: Number(userId),
                complaintId: Number(complaintId),
                message: message,
                issuedBy: Number(adminId),
            },
        });

        // Increment user's warning count
        const updatedUser = await prisma.user.update({
            where: { id: Number(userId) },
            data: { warningCount: { increment: 1 } },
        });

        // Update complaint status to REVIEWED
        const updatedComplaint = await prisma.complaint.update({
            where: { id: Number(complaintId) },
            data: { status: "REVIEWED" },
            include: {
                complainant: { select: { id: true, name: true } },
            }
        });

        // Notify the Accused
        await createNotification(
            userId,
            "Official Warning",
            `You have received an official warning: ${message}`,
            "WARNING"
        );

        // Notify the Complainant
        if (updatedComplaint.complainant) {
            await createNotification(
                updatedComplaint.complainant.id,
                "Complaint Reviewed",
                `Your complaint has been reviewed and a warning has been issued to the other party.`,
                "SUCCESS"
            );
        }

        return res.json({
            message: "Warning sent successfully",
            warning: warning,
            userRole: updatedUser.role
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to send warning" });
    }
};

// NEW METHOD: Ban passenger
exports.banPassenger = async (req, res) => {
    // NOTE: Ban logic is currently handled by another developer.
    // This is a placeholder to keep the endpoint functional.
    return res.json({
        message: "Ban request received. Processing by safety team.",
        status: "PENDING_REVIEW"
    });
};

// NEW METHOD: Get passenger complaint history
exports.getPassengerHistory = async (req, res) => {
    const passengerId = Number(req.params.passengerId);

    try {
        const complaints = await prisma.complaint.findMany({
            where: { passengerId: passengerId },
            include: {
                driver: { select: { name: true } },
                ride: { select: { origin: true, destination: true, departureTime: true } },
            },
            orderBy: { createdAt: "desc" },
        });

        const warnings = await prisma.warning.findMany({
            where: { userId: passengerId },
            include: { complaint: true },
        });

        return res.json({
            complaints: complaints,
            warnings: warnings,
            totalComplaints: complaints.length,
            totalWarnings: warnings.length,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to fetch passenger history" });
    }
};

// Passenger to Driver Complaint
exports.filePassengerToDriverComplaint = async (req, res) => {
    const { passengerId, driverId, rideId, description, severity } = req.body;

    try {
        const complaint = await prisma.complaint.create({
            data: {
                driverId: Number(driverId),
                passengerId: Number(passengerId),
                complainantId: Number(passengerId),
                rideId: Number(rideId),
                title: `Passenger complaint against driver`,
                description: description,
                severity: severity || "MEDIUM",
                type: "PASSENGER_TO_DRIVER",
                status: "PENDING",
            },
            include: {
                driver: { select: { name: true, email: true } },
                passenger: { select: { name: true, email: true } },
                ride: { select: { origin: true, destination: true } },
            },
        });

        // Notify driver
        await createNotification(
            driverId,
            "Complaint Filed Against You",
            `A passenger has filed a complaint against you. Admin will review it.`,
            "WARNING"
        );

        // Notify the complainant passenger
        await createNotification(
            passengerId,
            "Complaint Filed",
            `Your complaint against the driver has been filed successfully and is pending review.`,
            "SUCCESS"
        );

        return res.status(201).json({
            message: "Complaint filed successfully",
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to file complaint" });
    }
};

// Passenger to Passenger Complaint
exports.filePassengerToPassengerComplaint = async (req, res) => {
    const { complainantId, accusedId, rideId, description, severity, seatNo, timeRange } = req.body;

    try {
        const complaint = await prisma.complaint.create({
            data: {
                driverId: null,
                passengerId: Number(accusedId),
                complainantId: Number(complainantId),
                rideId: Number(rideId),
                title: `Passenger complaint against passenger`,
                description: description,
                severity: severity || "MEDIUM",
                type: "PASSENGER_TO_PASSENGER",
                status: "PENDING",
            },
            include: {
                passenger: { select: { name: true, email: true } },
                ride: { select: { origin: true, destination: true } },
            },
        });

        // Notify accused passenger
        await createNotification(
            accusedId,
            "Complaint Filed Against You",
            `A fellow passenger has filed a complaint against you. Admin will review it.`,
            "WARNING"
        );

        // Notify the complainant passenger
        await createNotification(
            complainantId,
            "Complaint Filed",
            `Your complaint against the fellow passenger has been filed successfully and is pending review.`,
            "SUCCESS"
        );

        return res.status(201).json({
            message: "Complaint filed successfully",
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to file complaint" });
    }
};