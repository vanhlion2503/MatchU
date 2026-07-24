require('./config/env'); const app = require('./app'); const { port, nodeEnv } = require('./config/env'); const logger = require('./utils/logger');
const server = app.listen(port, () => console.log(`MatchU Admin running on port ${port} (${nodeEnv})`));
process.on('unhandledRejection', (reason) => { logger.error('Unhandled rejection', reason); server.close(() => process.exit(1)); });
process.on('uncaughtException', (error) => { logger.error('Uncaught exception', error); process.exit(1); });
