# Brahma

Brahma is a life-management suite: separate apps that share one core and
one end-to-end encrypted sync account, and one app that holds them all.

- [Artha](https://github.com/sudharamachandranrajeev/artha): finance, accounting and investments
- [Anveshana](https://github.com/sudharamachandranrajeev/anveshana): property research, renting, buying,
  investment, development and management
- [Udyoga](https://github.com/sudharamachandranrajeev/udyoga): career and job search: matched openings,
  tailored CVs, applications, contacts, career paths, learning and interview practice
- [Vani](https://github.com/sudharamachandranrajeev/vani): social media: scheduled posts, one inbox,
  discovery alerts and analytics
- [Vidya](https://github.com/sudharamachandranrajeev/vidya): learning and knowledge: programs, courses,
  flashcards, skills, portfolio and progress

## Layout

- `app/`: **Brahma**, the suite app. Its home screen is a life dashboard with
  a live card per app; a card opens the app, in its own look, and "All apps"
  comes back. One sign-in and one sync account cover every app; each app
  keeps its own encrypted database.
- `apps/<name>/`: each app, as a git subtree of its own repository (with
  full history). The apps are developed in their own repositories and keep
  shipping on their own; Brahma pulls their updates in.
- `core/`: `brahma_core`, the Flutter package with the encrypted database,
  sync, pairing, the app frame and `SuiteApp`, the way an app describes
  itself to the suite
- `watch/`: Brahma Watch, the cloud watcher that pushes alerts to your phone
  and hosts Vani's social hub

## Updating the apps

Never edit `apps/<name>` here. Change the app's own repository and push,
then:

```sh
scripts/pull-apps.sh            # every app
scripts/pull-apps.sh udyoga     # one app
```

## Adding an app

1. In the app's repository, add `lib/suite.dart` exporting a `SuiteApp`
   (see any current app) and push.
2. Here: `git subtree add --prefix apps/<name> https://github.com/sudharamachandranrajeev/<name>.git main`
3. Add the path dependency to `app/pubspec.yaml` and the app to
   `app/lib/app/apps.dart`.

Core needs no change for a new app.

## Building the suite app

```sh
cd app
flutter test
flutter build linux --release      # or windows, apk
```

`BRAHMA_SHOTS=/tmp/shots flutter test test/screenshots_test.dart` renders the
home screen and a few hosted apps to PNG files.
