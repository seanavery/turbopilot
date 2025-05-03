#!/usr/bin/env python3
import time
import cereal.messaging as messaging

def normalize(value):
    # input: [-1, 1]
    # output: [0, 255]
    return float((value + 1) / 2 * 255)

def main():
    # create sub socket for g29
    g29_sock = messaging.sub_sock("g29")
    joystick_sock = messaging.PubMaster(['testJoystick'])

    while True:
        time.sleep(0.02) # 50 hz loop
        for msg in messaging.drain_sock(g29_sock, wait_for_one=True):
            if msg.which() == "g29":
                g29_data = msg.g29
                print(f"Steering: {g29_data.steering}, Accelerator: {g29_data.accelerator}")
                steering, accel = normalize(g29_data.steering), normalize(g29_data.accelerator)
                print(f"Normalized Steering: {steering}, Normalized Accelerator: {accel}")
                joystick_msg = messaging.new_message('testJoystick')
                joystick_msg.testJoystick.axes = [steering, accel]
                joystick_sock.send('testJoystick', joystick_msg)

            else:
                print("Unknown message type received")

if __name__ == "__main__":
    main()
