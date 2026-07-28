const Joi = require('joi');

const ALLOWED_RANGES = Object.freeze([7, 30, 90]);

const dashboardQuerySchema = Joi.object({
  range: Joi.number()
    .integer()
    .valid(...ALLOWED_RANGES)
    .default(7)
}).unknown(false);

function validateDashboardQuery(query) {
  return dashboardQuerySchema.validate(query, {
    abortEarly: false,
    convert: true,
    stripUnknown: false
  });
}

module.exports = {
  ALLOWED_RANGES,
  validateDashboardQuery
};
