const crypto = require('crypto');

module.exports = (req, res, next) => {
  req.id = crypto.randomUUID();
  res.setHeader('x-request-id', req.id);
  next();
};
