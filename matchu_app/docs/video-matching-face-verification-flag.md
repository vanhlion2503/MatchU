# Video matching face verification flag

Face enrollment and reauthentication remain enabled by default. The temporary
test bypass must be configured consistently in both the Flutter app and Cloud
Functions.

## Disable for testing

Run or build Flutter with:

```sh
flutter run --dart-define=VIDEO_MATCHING_FACE_VERIFICATION_ENABLED=false
```

Set the same variable for Cloud Functions (for example in the appropriate
Firebase Functions `.env.<project-id>` file), then deploy or restart the
emulator:

```dotenv
VIDEO_MATCHING_FACE_VERIFICATION_ENABLED=false
```

## Re-enable

Remove both overrides, or set both values to `true`. Since `true` is the
default, an unconfigured production build preserves the original verification
flow.
