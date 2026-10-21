# Memory Market for Android

Memory Market is a Flutter app for searching computer parts across Pakistani
online stores. It uses the FastAPI search service in `backend_user.py`
(`GET /search?q=...`, port **8000**).

## Build an APK with GitHub Actions

The repository includes a GitHub Actions workflow that builds a sideloadable
Android APK on GitHub-hosted runners. Android Studio is not required on your
computer.

1. Create a **public** GitHub repository and upload the contents of this
   `mobile_app` folder. Do not upload the bundled `flutter/`, `build/`,
   `.dart_tool/`, or `.idea/` folders; `.gitignore` excludes generated files
   and the bundled SDK.
2. Start your Cloudflare tunnel forwarding to the search service on port 8000.
   Keep the tunnel running while you use the app. The default workflow input
   is `https://republic-superior-members-converted.trycloudflare.com`; replace it
   when starting a build if your Quick Tunnel URL has changed.
3. In the GitHub repository, open **Actions**, select **Build Android APK**,
   choose **Run workflow**, and run it.
4. Open the completed workflow run, download the `memory-market-android-apk`
   artifact, unzip it, and transfer `app-release.apk` to your Android phone.
   Open the APK and allow your browser or file manager to install unknown
   apps if Android asks.

Because the repository is public, its source code and APK artifact are public.
The APK uses the temporary Cloudflare Quick Tunnel address provided at build
time; it will stop connecting if the tunnel stops or its address changes.
Only the search service is configured here. The separate featured-products
service on port 9000 is not included in this setup.

## Run locally

Install Flutter, connect an Android device with USB debugging enabled, and run
the following from this folder:

```powershell
flutter pub get
flutter run --dart-define=SEARCH_API_URL=https://your-tunnel.trycloudflare.com
```

The Android platform project is already generated in this folder. The Android
manifest includes internet access for API requests.

## Google Play

The GitHub Actions APK is for direct installation and testing, not Play Store
publishing. For a Play release, choose a permanent unique application ID,
configure a protected upload key, and build a signed Android App Bundle with a
stable HTTPS backend URL.
