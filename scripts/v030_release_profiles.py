#!/usr/bin/env python3
"""Immutable release-profile descriptors for the v0.3.0 publication paths."""

from __future__ import annotations

import sys


sys.dont_write_bytecode = True


FORMAL = {
    "releaseProfile": "formal",
    "tag": "v0.3.0",
    "evidencePath": "docs/validation/windows-v0.3.0.json",
    "realDeviceValidated": True,
}
QUICK_PRERELEASE = {
    "releaseProfile": "quick-prerelease",
    "tag": "v0.3.0-rc.1",
    "evidencePath": "docs/validation/windows-v0.3.0-quick-prerelease.json",
    "realDeviceValidated": False,
}
PROFILES = {
    FORMAL["releaseProfile"]: FORMAL,
    QUICK_PRERELEASE["releaseProfile"]: QUICK_PRERELEASE,
}


def profile(name: str) -> dict[str, object]:
    """Return the sole descriptor for an explicit supported profile."""
    try:
        return PROFILES[name]
    except KeyError as error:
        raise ValueError("unsupported v0.3.0 release profile") from error
