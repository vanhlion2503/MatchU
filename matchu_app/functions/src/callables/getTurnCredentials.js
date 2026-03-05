const { onCall, HttpsError } = require("firebase-functions/v2/https");
const axios = require("axios");

const {
  TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN,
} = require("../shared/secrets");

const getTurnCredentials = onCall(
  {
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const accountSid = (TWILIO_ACCOUNT_SID.value() || "").trim();
    const authToken = (TWILIO_AUTH_TOKEN.value() || "").trim();

    if (!accountSid || !authToken) {
      throw new HttpsError(
        "failed-precondition",
        "TURN provider secrets are not configured."
      );
    }

    try {
      const response = await axios.post(
        `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Tokens.json`,
        "",
        {
          auth: {
            username: accountSid,
            password: authToken,
          },
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          timeout: 8000,
        }
      );

      const rawIceServers = Array.isArray(response.data?.ice_servers)
        ? response.data.ice_servers
        : [];

      const iceServers = rawIceServers
        .map((server) => {
          if (!server || typeof server !== "object") return null;

          const urls = server.urls ?? server.url;
          if (!urls) return null;

          const out = { urls };
          if (typeof server.username === "string" && server.username) {
            out.username = server.username;
          }
          if (typeof server.credential === "string" && server.credential) {
            out.credential = server.credential;
          }
          return out;
        })
        .filter(Boolean);

      if (iceServers.length === 0) {
        throw new Error("Twilio returned no ICE servers.");
      }

      return {
        iceServers,
        ttl: typeof response.data?.ttl === "number" ? response.data.ttl : null,
      };
    } catch (error) {
      const status = error?.response?.status;
      const code = error?.response?.data?.code;
      const details = error?.response?.data?.message;

      console.error("Twilio ICE fetch failed:", {
        status,
        code,
        details,
        message: error?.message || String(error),
      });

      if (status === 401 || status === 403) {
        throw new HttpsError(
          "failed-precondition",
          "TURN provider credentials are invalid."
        );
      }

      if (status === 429) {
        throw new HttpsError(
          "resource-exhausted",
          "TURN provider rate limit exceeded. Try again shortly."
        );
      }

      throw new HttpsError(
        "internal",
        "Unable to fetch ICE servers from TURN provider."
      );
    }
  }
);

module.exports = {
  getTurnCredentials,
};
