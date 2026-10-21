# Brahma

Brahma is a life-management suite made of separate apps that share one core
and one end-to-end encrypted sync account:

- [Artha](https://github.com/sudharamachandranrajeev/artha): finance, accounting and investments
- [Anveshana](https://github.com/sudharamachandranrajeev/anveshana): property research, renting, buying,
  investment, development and management

This repository holds what they share:

- `core/`: `brahma_core`, the Flutter package with the encrypted database,
  sync, pairing and the app frame
- `watch/`: Brahma Watch, the cloud watcher that pushes alerts to your phone
