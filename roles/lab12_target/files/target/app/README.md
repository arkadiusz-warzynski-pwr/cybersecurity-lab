# Salary app source (vector B: Log4Shell)

The Spring "salary" app is vendored here as `pom.xml`, `src/` and `data/` (the
display records), taken from the instructor's Log4Shell project and adapted for
the lab:

- **De-flagged:** the CTF flag and `challenge.yml` are not shipped; `data/` must
  not embed a flag. The lab measures RCE + escalation, not a captured flag.
- **Vulnerable config kept:** Log4J 2.14.1, `trustURLCodebase=true`,
  `formatMsgNoLookups=false`. The sink is the login `username` (logged via Log4J).
- **Runs non-root** (user `app` in the container), so the foothold is unprivileged.

Stage 2 of the Dockerfile builds it (`maven:3.8.6-openjdk-8`); the final image
runs the resulting jar as `app`. Nothing needs to be populated here by hand.
