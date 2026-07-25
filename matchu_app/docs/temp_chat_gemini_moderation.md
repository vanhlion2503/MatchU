# Temp chat moderation with Gemini

## Runtime flow

1. `TempChatController` sends a message through `TempChatRepository`.
2. `TempChatService` writes the message to Firestore with `status: pending`.
3. `moderateTempChatMessage` applies local rules and safe-message fast paths.
4. Messages that still need semantic classification are sent to
   `gemini-3.5-flash-lite`.
5. The Cloud Function keeps the existing Firestore contract:
   `approved`, `blocked`, `warning`, `reason`, and `aiScore`.
6. The existing temp-chat UI reacts to the status update without calling
   Gemini or storing an API key on the device.

## Production configuration

The project already declares `GEMINI_API_KEY` through Firebase Secret Manager.
If the secret has not been created in a new Firebase project, set it once:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

Deploy the changed trigger:

```bash
firebase deploy --only functions:moderateTempChatMessage
```

After deployment, verify at least these cases in a test room:

- a greeting is approved immediately;
- an ordinary Vietnamese chat sentence is approved after Gemini;
- obfuscated abusive language is blocked;
- Vietnamese profanity such as `chán vcl` is blocked by the local fast rule;
- sexual-service solicitation such as `em có đi khách không em` is blocked;
- a scam-like message preserves the existing warning behavior;
- a Gemini timeout still resolves the message through the existing fallback.

The legacy `ai_moderation` service is no longer referenced by temp chat. Keep it
temporarily for rollback, then decommission its Cloud Run deployment after the
Gemini trigger has passed production monitoring.
