#!/usr/bin/env python3
from openpilot.common.params import Params
from openpilot.system.hardware import PC
import sys

if __name__ == "__main__":
    params = Params()
    if "-down" in sys.argv:
        params.put("GCS", "0")
        sys.exit()
    if PC:
        params.put("GCS", "1")
        print("Turbo enabled")
