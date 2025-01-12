const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

// Initialize express and the HTTP server
const app = express();
const server = http.createServer(app);

// Attach Socket.IO to the server
const io = new Server(server);

// Serve a static HTML file (optional, for testing)
app.get('/', (req, res) => {
  console.log("GET");
});

// Listen for client connections
io.on('connection', (socket) => {
  console.log('A user connected:', socket.id);
  io.emit('message', "Hello!");

  // Handle events from the client
  socket.on('message', (msg) => {
    console.log('Message received:', msg);

    // Broadcast the message to all connected clients
    io.emit('message', msg);
  });

  // Handle events from the client
  socket.on('test', (msg) => {
    console.log('Message test received:', msg);

    // Broadcast the message to all connected clients
    io.emit('message', "Test received");
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log('A user disconnected:', socket.id);
  });
});

// Start the server
const PORT = 3000;
server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
