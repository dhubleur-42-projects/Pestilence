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
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher.o $WORK_FOLDER/TMP_main_without_uncipher.s
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher.o | grep -E "^[0-9a-z].*TMP_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_uncipher.o | grep -E "^[0-9a-z].*TMP_END_anti_debugging.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep -E "^[0-9a-z].*TMP_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	objdump -F -d --show-all-symbols $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep -E "^[0-9a-z].*TMP_END_uncipher.*File Offset" | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc
	exit
	python xor.py
	xxd -g1 magic_key | perl -pe 's/^[0-9a-z]*: ((?:[0-9a-z]{2} )*) .*$/db \1/' > magic_key.s
	perl -pie 's/([0-9a-z])/0x\1/g' magic_key.s
}

same_size_between_payloads()
{
	perl -0777 -pe 's/\.TMP_anti_debugging:.*\.TMP_END_anti_debugging://s' main.s > $WORK_FOLDER/TMP_main_without_anti_debugging.s
	perl -0777 -pe 's/\.TMP_uncipher:.*\.TMP_END_uncipher://s' main.s > $WORK_FOLDER/TMP_main_without_uncipher.s

	# TODO Change ../ with absolute path from this script or cd
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher.o $WORK_FOLDER/TMP_main_without_uncipher.s
	without_anti_debugging_size=$(stat -c%s "$WORK_FOLDER/TMP_main_without_anti_debugging.o")
	without_ciphering_size=$(stat -c%s "$WORK_FOLDER/TMP_main_without_uncipher.o")
	if [[ $without_anti_debugging_size -lt $without_ciphering_size ]]; then
		diff_size=$((without_ciphering_size-without_anti_debugging_size))
		sed -i -E "s/(\.TMP_END_uncipher:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_anti_debugging.s"

	elif [[ $without_anti_debugging_size -gt $without_ciphering_size ]]; then
		diff_size=$((without_anti_debugging_size-without_ciphering_size))
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
