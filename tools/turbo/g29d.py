#!/usr/bin/env python3
from g29py import G29

def main():
    # connect to wheel/pedal
    g29 = G29()

    # set autocenter
    g29.set_range(500)
    g29.set_autocenter(0.25, 0.25)

if __name__ == "__main__":
    main()