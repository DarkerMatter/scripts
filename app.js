const express = require('express');
const path = require('path');
const logger = require('morgan');
const cookieParser = require('cookie-parser');
const createError = require('http-errors');
require('dotenv').config();  // Load environment variables

const app = express();

app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'pug');

app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

// Route to serve the scripts
app.get('/api/download/:scriptName', (req, res) => {
  const scriptName = req.params.scriptName;
  const scriptPath = path.join(__dirname, 'scripts', scriptName);

  res.download(scriptPath, (err) => {
    if (err) {
      console.error(`Error downloading ${scriptName}:`, err);
      res.status(404).send('Script not found');
    }
  });
});

// Home Route
app.get('/', (req, res) => {
  res.render('index', {
    title: 'Script Downloader',
    baseUrl: process.env.BASE_URL
  });
});

// Catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// Error handler
app.use(function(err, req, res, next) {
  // Set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // Render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;