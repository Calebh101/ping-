const WebSocket = require('ws');

// Create a WebSocket server
const wss = new WebSocket.Server({ port: 9009 });

console.log('WebSocket server is listening on ws://localhost:9009');

wss.on('connection', (ws) => {
    console.log('New client connected');

    // Handle messages from the client
    ws.on('message', (message) => {
        console.log(`Received message: ${message}`);

        // Echo the message back to the client
        ws.send(`Server: You said "${message}"`);
    });

    // Handle client disconnection
    ws.on('close', () => {
        console.log('Client disconnected');
    });

    // Send a welcome message to the client
    ws.send('Welcome to the WebSocket server!');
});
