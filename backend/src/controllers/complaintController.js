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

        await createNotification(
            driverId,
            "Complaint Filed",
            `Your complaint against the passenger has been filed successfully and is pending review.`,
            "SUCCESS"
        );

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
// Existing getComplaints method (FIXED - added complainant)
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
                complainant: { select: { id: true, name: true, email: true } }, // ← ADD THIS LINE
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
// Existing getComplaintById (FIXED - added complainant)
exports.getComplaintById = async (req, res) => {
    const complaintId = Number(req.params.id);

    try {
        const complaint = await prisma.complaint.findUnique({
            where: { id: complaintId },
            include: {
                driver: { select: { id: true, name: true, email: true, phone: true } },
                passenger: { select: { id: true, name: true, email: true, phone: true, warningCount: true, isBanned: true } },
                complainant: { select: { id: true, name: true, email: true } }, // ← ADD THIS LINE
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

        if (complaint.complainant) {
            await createNotification(
                complaint.complainant.id,
                "Complaint Update",
                `Your complaint #${complaintId} has been marked as ${status.toLowerCase()}.`,
                status === "RESOLVED" ? "SUCCESS" : "INFO"
            );
        }

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
    const { complaintId, userId, message } = req.body;

    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: "Unauthorized" });
    }
    const adminId = authHeader.split(' ')[1];

    try {
        const warning = await prisma.warning.create({
            data: {
                userId: Number(userId),
                complaintId: Number(complaintId),
                message: message,
                issuedBy: Number(adminId),
            },
        });

        const updatedUser = await prisma.user.update({
            where: { id: Number(userId) },
            data: { warningCount: { increment: 1 } },
        });

        const updatedComplaint = await prisma.complaint.update({
            where: { id: Number(complaintId) },
            data: { status: "REVIEWED" },
            include: {
                complainant: { select: { id: true, name: true } },
            }
        });

        await createNotification(
            userId,
            "Official Warning",
            `You have received an official warning: ${message}`,
            "WARNING"
        );

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

        await createNotification(
            driverId,
            "Complaint Filed Against You",
            `A passenger has filed a complaint against you. Admin will review it.`,
            "WARNING"
        );

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

// ============ NEW: Passenger to Passenger Complaint ============
exports.filePassengerToPassengerComplaint = async (req, res) => {
    const { complainantId, accusedId, rideId, description, severity, seatNo, reportType, timeRange } = req.body;

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
                metadata: {
                    seatNo: seatNo,
                    reportType: reportType || "DELAYED",
                    timeRange: timeRange || null
                }
            },
            include: {
                passenger: { select: { name: true, email: true } },
                ride: { select: { origin: true, destination: true, departureTime: true } },
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

        // Notify admins
        const admins = await prisma.user.findMany({
            where: { role: "ADMIN" },
            select: { id: true }
        });

        for (const admin of admins) {
            await createNotification(
                admin.id,
                "New Complaint Filed",
                `New passenger-to-passenger complaint for ride #${rideId}`,
                "INFO"
            );
        }

        return res.status(201).json({
            message: "Complaint filed successfully",
            complaint: {
                id: complaint.id,
                status: complaint.status,
                createdAt: complaint.createdAt,
            },
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to file complaint" });
    }
};

// ============ NEW: Identify passenger by seat (Immediate) ============
exports.identifyPassengerBySeat = async (req, res) => {
    const { rideId, seatNo } = req.body;

    if (!rideId || !seatNo) {
        return res.status(400).json({ error: "rideId and seatNo are required" });
    }

    try {
        const booking = await prisma.seatBooking.findFirst({
            where: {
                rideId: Number(rideId),
                seatNo: Number(seatNo),
                paidAt: null,
            },
            include: {
                user: {
                    select: {
                        id: true,
                    }
                }
            }
        });

        if (!booking) {
            return res.status(404).json({
                error: "No active passenger found in that seat"
            });
        }

        return res.json({
            passenger: {
                id: booking.user.id,
            },
            seatNo: booking.seatNo,
            isActive: true,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to identify passenger" });
    }
};

// ============ NEW: Identify passenger by seat and time range (Delayed) ============
exports.identifyPassengerBySeatAndTime = async (req, res) => {
    const { rideId, seatNo, startTime, endTime } = req.body;

    if (!rideId || !seatNo || !startTime || !endTime) {
        return res.status(400).json({
            error: "rideId, seatNo, startTime, and endTime are required"
        });
    }

    try {
        const booking = await prisma.seatBooking.findFirst({
            where: {
                rideId: Number(rideId),
                seatNo: Number(seatNo),
                createdAt: { lte: new Date(endTime) },
                OR: [
                    { paidAt: null },
                    { paidAt: { gte: new Date(startTime) } }
                ]
            },
            include: {
                user: {
                    select: {
                        id: true,
                    }
                }
            },
            orderBy: { createdAt: 'desc' },
            take: 1,
        });

        if (!booking) {
            return res.status(404).json({
                error: "No passenger found in that seat during the specified time range"
            });
        }

        // Verify the time range
        const bookingTime = new Date(booking.createdAt);
        const paidTime = booking.paidAt ? new Date(booking.paidAt) : null;
        const start = new Date(startTime);
        const end = new Date(endTime);

        let wasInSeat = false;

        if (paidTime) {
            wasInSeat = (bookingTime <= end && paidTime >= start);
        } else {
            wasInSeat = (bookingTime <= end);
        }

        if (!wasInSeat) {
            return res.status(404).json({
                error: "Passenger was not in that seat during the specified time"
            });
        }

        return res.json({
            passenger: {
                id: booking.user.id,
            },
            seatNo: booking.seatNo,
            bookingTime: booking.createdAt,
            departureTime: booking.paidAt,
            wasPresent: true,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to identify passenger" });
    }
};

// ============ NEW: Get ride seat map (Privacy-focused) ============
exports.getRideSeatMap = async (req, res) => {
    const rideId = Number(req.params.rideId);
    const currentUserId = req.headers.authorization ?
        Number(req.headers.authorization.split(' ')[1]) : null;

    if (!rideId) {
        return res.status(400).json({ error: "rideId is required" });
    }

    try {
        const ride = await prisma.ride.findUnique({
            where: { id: rideId },
            select: { seats: true }
        });

        const bookings = await prisma.seatBooking.findMany({
            where: {
                rideId: rideId,
                paidAt: null,
            },
            include: {
                user: {
                    select: {
                        id: true,
                    }
                }
            }
        });

        const seats = [];
        for (let i = 1; i <= (ride?.seats || 4); i++) {
            const booking = bookings.find(b => b.seatNo === i);
            if (booking) {
                const isSelf = currentUserId ? booking.user.id === currentUserId : false;
                seats.push({
                    seatNo: i,
                    isOccupied: true,
                    isSelf: isSelf,
                });
            } else {
                seats.push({
                    seatNo: i,
                    isOccupied: false,
                    isSelf: false,
                });
            }
        }

        const mySeatBooking = currentUserId ? bookings.find(b => b.user.id === currentUserId) : null;

        return res.json({
            rideId: rideId,
            totalSeats: ride?.seats || 4,
            seats: seats,
            mySeat: mySeatBooking?.seatNo || null,
        });
    } catch (err) {
        console.error(err);
        return res.status(500).json({ error: "Failed to fetch seat map" });
    }
};