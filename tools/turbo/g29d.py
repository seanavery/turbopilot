#!/usr/bin/env python3
import time
from g29py import G29
import cereal.messaging as messaging

def main():
    # connect to wheel/pedal
    g29 = G29()

    # set autocenter
    g29.set_range(500)
    g29.set_autocenter(0.25, 0.25)

    messaging.context = messaging.Context()
    g29_sock = messaging.pub_sock("g29")

    g29.listen()
    while True:
        time.sleep(0.02) # 50 hz loop
        state = g29.get_state()
        print(state["accelerator"], state["steering"])
        g29_data = messaging.new_message("g29")
        g29_data.g29.steering = state["steering"]
        g29_data.g29.accelerator = state["accelerator"]
        g29_sock.send(g29_data.to_bytes())


if __name__ == "__main__":
    main()
