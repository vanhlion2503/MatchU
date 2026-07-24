const { nodeEnv } = require('../config/env');
function error(message, err) { console.error(message, nodeEnv === 'production' ? undefined : err?.stack || err); }
module.exports = { error };
