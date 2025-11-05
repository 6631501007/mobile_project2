// Install packages: npm init -y, npm install express, npm install mysql2, npm install bcrypt, npm install -g nodemon, dart pub add http, npm install multer
// Run server: nodemon server_mobile.js / npx nodemon server_mobile.js

const mysql = require("mysql2");
const con = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: '',
    database: 'mobile_project2'
});


module.exports = con;