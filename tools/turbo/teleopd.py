#!/usr/bin/env python3
import time
import cereal.messaging as messaging

def main():
    # create sub socket for g29
    g29_sock = messaging.sub_sock("g29")

    while True:
        time.sleep(0.02) # 50 hz loop
        # receive g29 data
        for msg in messaging.drain_sock(g29_sock, wait_for_one=True):
            if msg.which() == "g29":
                g29_data = msg.g29
                print(f"Steering: {g29_data.steering}, Accelerator: {g29_data.accelerator}")
            else:
                print("Unknown message type received")


if __name__ == "__main__":
    main()