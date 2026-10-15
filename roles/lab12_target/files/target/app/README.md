# Salary app source

The Spring "salary" app is vendored here as `pom.xml`, `src/` and `data/` (the
display records). Stage 2 of the Dockerfile builds it with
`maven:3.8.6-openjdk-8`; the final image runs the resulting jar as the non-root
`app` user. Nothing here needs to be filled in by hand.

The pinned dependency versions and the runtime flags are deliberate — do not
upgrade or "harden" them. The reasons are recorded in the maintainer's
workspace notes rather than in this repository.
