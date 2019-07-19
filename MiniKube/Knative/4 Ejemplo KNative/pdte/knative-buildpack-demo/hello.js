const express = require('express');
const app = express();

app.get('/', function (req, res) {
    res.send("Hello from Buildpacks v1!");
});

var port = 8080;
app.listen(port, function () {
    console.log('Hello world listening on port',  port);
});
