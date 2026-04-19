require("dotenv").config();
const http = require("http");
const socketIo = require("socket.io");
const app = require("./app");
const socketHub = require("./lib/socketHub");

const server = http.createServer(app);
const io = socketIo(server);
socketHub.attach(io);

io.on("connection", (socket) => {
  console.log("A user connected");
  socket.on("disconnect", () => {
    console.log("A user disconnected");
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
