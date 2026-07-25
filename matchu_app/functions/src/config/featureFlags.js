function isVideoMatchingFaceVerificationEnabled(
  value = process.env.VIDEO_MATCHING_FACE_VERIFICATION_ENABLED
) {
  // Secure by default: only an explicit "false" disables the admission gate.
  return String(value ?? "true").trim().toLowerCase() !== "false";
}

module.exports = {
  isVideoMatchingFaceVerificationEnabled,
};
