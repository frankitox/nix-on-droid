# Nix-on-Droid (fork with supervisord support)

This is a fork of [nix-community/nix-on-droid](https://github.com/nix-community/nix-on-droid)
that adds

- A `supervisord` module, enabling long-running background services on Android via [supervisord](http://supervisord.org/).
- Support for notifications via Termux API fork

See the **[module options documentation](https://frankitox.github.io/nix-on-droid/)** for all
available options, including the new `supervisord` and `services.openssh` modules.

## Usage

- Download Termux APK from [frankitox/nix-on-droid-app](https://github.com/frankitox/nix-on-droid-app/actions/workflows/debug_build.yml)
- Download API APK from [frankitox/termux-api](https://github.com/frankitox/termux-api/actions/workflows/github_action_build.yml)
- Use `https://github.com/frankitox/nix-on-droid/releases/tag/2026-05-28-131313` as the bootstrap zip URL


```
unzip -p termux.zip "*.apk" > /tmp/app.apk && adb install /tmp/app.apk
```
