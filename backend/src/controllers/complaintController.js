const prisma = require("../lib/prisma");

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
                passenger: { select: { id: true, name: true, email: true, phone: true } },
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

exports.getComplaintById = async (req, res) => {
    const complaintId = Number(req.params.id);

    try {
        const complaint = await prisma.complaint.findUnique({
            where: { id: complaintId },
            include: {
                driver: { select: { id: true, name: true, email: true, phone: true } },
                passenger: { select: { id: true, name: true, email: true, phone: true } },
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

exports.updateComplaintStatus = async (req, res) => {
    const complaintId = Number(req.params.id);
    const { status, adminNotes } = req.body;

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
                driver: { select: { name: true, email: true } },
                passenger: { select: { name: true, email: true } },
            },
        });

        return res.json({
            message: `Complaint ${status.toLowerCase()} successfully`,
            complaint: complaint,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Internal server error" });
    }
};