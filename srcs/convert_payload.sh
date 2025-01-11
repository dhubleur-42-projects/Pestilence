#!/bin/bash
set -euo pipefail
WORK_FOLDER=$(mktemp -d /tmp/pestilence_convert_payloadXXXX)
trap cleanup EXIT

cleanup()
{
#	rm -r "$WORK_FOLDER"
	true
}

main()
{
	same_size_between_payloads
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging2.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher2.o $WORK_FOLDER/TMP_main_without_uncipher.s
	# DEBUG SHOULD BE THE SAME BY PAIR
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher2.o | grep -E "^[0-9a-z].*TMP_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher2.o | grep -E "^[0-9a-z].*TMP_END_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep -E "^[0-9a-z].*TMP_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep -E "^[0-9a-z].*TMP_END_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc

	START=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher2.o | grep -E "^[0-9a-z].*TMP_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	END=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher2.o | grep -E "^[0-9a-z].*TMP_END_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	cat $WORK_FOLDER/TMP_main_without_uncipher2.o | head -c+$END | tail -c+$START > anti_debugging.bin
	cat $WORK_FOLDER/TMP_main_without_anti_debugging2.o | head -c+$END | tail -c+$START > ciphering.bin
	python xor.py
	xxd -g1 magic_key.bin | perl -pe 's/^[0-9a-z]*: ((?:[0-9a-z]{2} )*) .*$/\1/' > magic_key.s
	perl -i -pe 's/([0-9a-z]{2})/0x\1/g' magic_key.s
	sed -i 's/^/db /' magic_key.s
}

same_size_between_payloads()
{
	perl -0777 -pe 's/\.TMP_anti_debugging:.*\.TMP_END_anti_debugging://s' main.s > $WORK_FOLDER/TMP_main_without_anti_debugging.s
	perl -0777 -pe 's/\.TMP_uncipher:.*\.TMP_END_uncipher://s' main.s > $WORK_FOLDER/TMP_main_without_uncipher.s

	# TODO Change ../ with absolute path from this script or cd
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher.o $WORK_FOLDER/TMP_main_without_uncipher.s
	start_offset=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher.o | grep -E "^[0-9a-z].*TMP_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	end_offset=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher.o | grep -E "^[0-9a-z].*TMP_END_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	anti_debugging_size=$((end_offset-start_offset))
	start_offset=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep -E "^[0-9a-z].*TMP_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	end_offset=$(objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep -E "^[0-9a-z].*TMP_END_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	cipher_size=$((end_offset-start_offset))
	if [[ $cipher_size -lt $anti_debugging_size ]]; then
		diff_size=$((anti_debugging_size-cipher_size))
		sed -i -E "s/(\.TMP_END_uncipher:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
	fi

	if [[ $cipher_size -gt $anti_debugging_size ]]; then
		diff_size=$((cipher_size-anti_debugging_size))
		sed -i -E "s/(\.TMP_END_anti_debugging:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_uncipher.s"
	fi
}

# 'shuf reads all input before opening OUTPUT-FILE, so you can safely shuffle a file in place
# Cf. $> info shuf
# Cf. https://stackoverflow.com/a/55655338/8371072	
write_to()
{
	file="$1"
	shuf --output="$file" --random-source=/dev/zero 
}

main "$@"
