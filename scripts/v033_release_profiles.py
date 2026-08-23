"""Immutable release-profile descriptors for the v0.3.3 publication path."""

from __future__ import annotations

import sys
from types import MappingProxyType


sys.dont_write_bytecode = True


FORMAL = MappingProxyType({
    "releaseProfile": "formal",
    "tag": "v0.3.3",
    "evidencePath": "docs/validation/windows-v0.3.3.json",
    "realDeviceValidated": True,
})
