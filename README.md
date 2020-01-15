# sdc-amon-relay

**This is an experimental repository and is not yet production-ready**

*For now, the actual amon relay code used by Triton/Manta components is available at https://github.com/joyent/sdc-amon/*

This repository is part of the Joyent Triton project. See the [contribution
guidelines](https://github.com/joyent/triton/blob/master/CONTRIBUTING.md)
and general documentation at the main
[Triton project](https://github.com/joyent/triton) page.

The Triton Amon relay. This Triton component is deployed to all server
global zones. It is responsible for fetching probe configs from the
amon-master, relaying those to amon-agents on that server (both in the GZ and
in zones), and relaying Amon events up from amon-agents up to the master.
Communication with amon-agents in zones is via a "zone socket" that the
relay opens at the well-known path in the zone.


## Usage

For now, use the source.


## Development

The following sections are about developing this module.

### Building

    make all release publish

To build and actually publish an "amon-relay" image to an IMGAPI
repository (typically updates.joyent.com), use:

    ENGBLG_BITS_UPLOAD_IMAGE=true
    make all release publish bits-upload

### Commiting

Before commit, ensure that the following passes:

    make check

### Releasing

Changes with possible user impact should:

1. Add a note to the [changelog](./CHANGES.md).
2. Bump the package version appropriately (major for breaking changes, minor
   for new features, patch for bug fixes).
3. Once merged to master, the new version should be tagged (currently this
   does not publish to npm) via:

        make cutarelease
