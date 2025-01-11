#!/bin/python3
anti_debugging_data=None
ciphering_data=None
with open('anti_debugging.bin', 'rb') as anti_debugging_file:
    anti_debugging_data = anti_debugging_file.read()
with open('ciphering.bin', 'rb') as ciphering_file:
    ciphering_data = ciphering_file.read()
if len(anti_debugging_data) != len(ciphering_data):
    print(f"len(anti_debugging_file) = {len(anti_debugging_data)} != len(ciphering_file) = {len(ciphering_data)}")
    exit(1)
with open('magic_key.bin', 'wb') as magic_key_file:
    for i in range(len(anti_debugging_data)):
        magic_key_file.write((anti_debugging_data[i] ^ ciphering_data[i]).to_bytes(1, 'little'))
