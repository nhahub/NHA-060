const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>App 1</title></head>
      <body style="background-color: #f0f8ff;">
        <h1> Application 1</h1>
        <p>Server: ${req.headers.host}</p>
        <p>Time: ${new Date().toLocaleString()}</p>
        <p>This is Load Balanced App 1</p>
      </body>
    </html>
  `);
});

app.listen(PORT, () => {
  console.log(`App 1 running on port ${PORT}`);
});