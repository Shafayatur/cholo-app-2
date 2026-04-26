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
                passenger: { select: { name: true, email: true } },
            },
        });

        // Notify Driver
        await createNotification(
            complaint.driver.id,
            "Complaint Update",
            `Your complaint against ${complaint.passenger.name} has been marked as ${status.toLowerCase()}.`,
            status === "RESOLVED" ? "SUCCESS" : "INFO"
        );

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
    const { complaintId, passengerId, message } = req.body;

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
                passengerId: Number(passengerId),
                complaintId: Number(complaintId),
                message: message,
                issuedBy: Number(adminId),
            },
        });

        // Increment passenger's warning count
        await prisma.user.update({
            where: { id: Number(passengerId) },
            data: { warningCount: { increment: 1 } },
        });

        // Update complaint status to REVIEWED
        const updatedComplaint = await prisma.complaint.update({
            where: { id: Number(complaintId) },
            data: { status: "REVIEWED" },
            include: {
                driver: { select: { id: true } },
                passenger: { select: { name: true } }
            }
        });

        // Notify Passenger
        await createNotification(
            passengerId,
            "Official Warning",
            `You have received an official warning: ${message}`,
            "WARNING"
        );

        // Notify Driver
        await createNotification(
            updatedComplaint.driver.id,
            "Complaint Reviewed",
            `Your complaint against ${updatedComplaint.passenger.name} has been reviewed and a warning has been issued.`,
            "SUCCESS"
        );

        return res.json({
            message: "Warning sent successfully",
            warning: warning,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to send warning" });
    }
};

// NEW METHOD: Ban passenger
exports.banPassenger = async (req, res) => {
    const { passengerId, duration, reason, complaintId } = req.body;
    console.log(`Banning passenger ${passengerId} for complaint ${complaintId}. Duration: ${duration}`);

    try {
        let banExpiryDate = null;
        let isPermanent = false;

        if (duration === "temporary") {
            // 7 days ban
            banExpiryDate = new Date();
            banExpiryDate.setDate(banExpiryDate.getDate() + 7);
        } else if (duration === "permanent") {
            isPermanent = true;
            banExpiryDate = null;
        }

        // 1. Update User Record
        await prisma.user.update({
            where: { id: Number(passengerId) },
            data: {
                isBanned: true,
                banReason: reason,
                banExpiryDate: banExpiryDate,
            },
        });

        // 2. Update Complaint Status
        let updatedComplaint;
        if (complaintId) {
            updatedComplaint = await prisma.complaint.update({
                where: { id: Number(complaintId) },
                data: { status: "RESOLVED" },
                include: {
                    driver: { select: { id: true } },
                    passenger: { select: { name: true } }
                }
            });
            console.log(`Complaint ${complaintId} status updated to RESOLVED`);
        }

        // 3. Create Notifications
        const banMsg = duration === "permanent" ? "permanently banned" : "banned for 7 days";

        // Notify Passenger
        await createNotification(
            passengerId,
            "Account Sanction",
            `Your account has been ${banMsg} due to: ${reason}`,
            "DANGER"
        );

        // Notify Driver (if complaint exists)
        if (updatedComplaint) {
            await createNotification(
                updatedComplaint.driver.id,
                "Complaint Resolved",
                `Your complaint against ${updatedComplaint.passenger.name} has been resolved. The passenger has been ${banMsg}.`,
                "SUCCESS"
            );
        }

        return res.json({
            message: duration === "permanent" ? "Passenger permanently banned" : "Passenger banned for 7 days",
            status: "RESOLVED"
        });
    } catch (err) {
        console.error("Error in banPassenger:", err);
        return res.status(500).json({ error: "Failed to ban passenger", details: err.message });
    }
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
            where: { passengerId: passengerId },
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

        return res.status(201).json({
            message: "Complaint filed successfully",
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to file complaint" });
    }
};