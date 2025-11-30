const express = require('express');
const app = express();
const PORT = process.env.PORT || 3001;  // ← Changed to 3001

app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>App 2</title></head>
      <body style="background-color: #fff0f5;">
        <h1>🚀 Application 2</h1>
        <p>Server: ${req.headers.host}</p>
        <p>Time: ${new Date().toLocaleString()}</p>
        <p>This is Load Balanced App 2</p>
      </body>
    </html>
  `);
});

app.listen(PORT, () => {
  console.log(`App 2 running on port ${PORT}`);
});