const Joi = require('joi');
const sessionSchema = Joi.object({ idToken: Joi.string().trim().min(10).required(), rememberMe: Joi.boolean().required() });
function validateSession(body) { const { error, value } = sessionSchema.validate(body, { abortEarly: true, stripUnknown: true }); return { error, value }; }
module.exports = { validateSession };
