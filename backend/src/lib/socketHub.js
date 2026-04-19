/** Socket.IO instance set from server.js so routes can emit without circular imports. */
let ioInstance = null;

module.exports = {
  attach(io) {
    ioInstance = io;
  },
  emitFareUpdate(payload) {
    if (ioInstance) {
      ioInstance.emit("fareUpdate", payload);
    }
  },
};
