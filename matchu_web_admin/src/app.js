const express = require('express'); const path = require('path'); const cookieParser = require('cookie-parser'); const helmet = require('helmet'); const morgan = require('morgan'); const layouts = require('express-ejs-layouts');
const routes = require('./routes'); const locals = require('./middlewares/locals.middleware'); const notFound = require('./middlewares/not-found.middleware'); const errorHandler = require('./middlewares/error.middleware'); const { standard } = require('./middlewares/rate-limit.middleware');
const app = express();
app.disable('x-powered-by'); app.set('trust proxy', 1); app.set('view engine', 'ejs'); app.set('views', path.join(__dirname, 'views')); app.set('layout', 'layouts/auth-layout');
app.use(helmet({
  crossOriginEmbedderPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'", 'https://cdn.jsdelivr.net', 'https://www.gstatic.com'],
      styleSrc: ["'self'", "'unsafe-inline'", 'https://cdn.jsdelivr.net'],
      fontSrc: ["'self'", 'https://cdn.jsdelivr.net'],
      connectSrc: ["'self'", 'https://identitytoolkit.googleapis.com', 'https://securetoken.googleapis.com']
    }
  }
})); // TODO: replace unsafe-inline with nonces/hashes when CSP is tightened.
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev')); app.use(standard); app.use(express.urlencoded({ extended: false, limit: '20kb' })); app.use(express.json({ limit: '20kb' })); app.use(cookieParser()); app.use(express.static(path.join(__dirname, '..', 'public'))); app.use(layouts); app.use(locals);
app.use(routes); app.use(notFound); app.use(errorHandler);
module.exports = app;
