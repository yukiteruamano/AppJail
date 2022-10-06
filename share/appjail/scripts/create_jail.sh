#!/bin/sh
#
# Copyright (c) 2022, Jesús Daniel Colmenares Oviedo <DtxdF@disroot.org>
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

main()
{
	local _o
	local config
	local jail_conf jail_name jail_temp jail_user
	local opt_remove opt_chroot opt_enter
	local chroot_program
	local dirs

	if [ $# -eq 0 ]; then
		help
		return 64 # EX_USAGE
	fi

	opt_remove=1
	opt_chroot=1
	opt_enter=1
	jail_user="root"
	chroot_program="/bin/sh"

	while getopts ":clrd:u:t:n:p:C:" _o; do
		case "${_o}" in
			d)
				dirs="${dirs} ${OPTARG}"
				;;
			p)
				chroot_program="${OPTARG}"
				;;
			u)
				jail_user="${OPTARG}"
				;;
			r)
				opt_remove=0
				;;
			c)
				opt_chroot=0
				;;
			l)
				opt_enter=0
				;;
			t)
				jail_conf="${OPTARG}"
				;;
			n)
				jail_name="${OPTARG}"
				;;
			C)
				config="${OPTARG}"
				;;
			*)
				usage
				exit 64 # EX_USAGE
				;;
		esac
	done

	if [ -z "${jail_name}" -o -z "${jail_conf}" -o -z "${config}" ]; then
		usage
		exit 64 # EX_USAGE
	fi

	if [ ! -f "${config}" ]; then
		echo "Configuration file \`${config}\` does not exists or you don't have permission to read it." >&2
		exit 66 # EX_NOINPUT
	fi

	. "${config}"
	. "${LIBDIR}/sysexits"
	. "${LIBDIR}/log"
	
	jail_conf="${TEMPLATES}/${jail_conf}"
	if [ ! -f "${jail_conf}" ]; then
		lib_err ${EX_NOINPUT} "The \`${jail_conf}\` template does not exists or you don't have permission to read it."
	fi

	. "${LIBDIR}/replace"

	lib_replace_jaildir

	if [ ! -d "${JAILDIR}/${jail_name}" ]; then
		lib_err ${EX_NOINPUT} "The \`${jail_name}\` jail does not exists."
	fi

	. "${LIBDIR}/copy"

	if [ ! -z "${dirs}" ]; then
		lib_debug "Copying ${dirs} to ${JAILDIR}/${jail_name}..."
		lib_rcopy "${JAILDIR}/${jail_name}" ${dirs}
	fi

	. "${LIBDIR}/jail"

	set -e
	set -o pipefail

	if [ $opt_chroot -eq 1 ]; then
		lib_chroot_jail "${jail_name}" "${chroot_program}"
	fi

	. "${LIBDIR}/tempfile"

	lib_debug "Editing the template..."

	jail_temp="`lib_filter_jail \"${jail_name}\" \"${jail_conf}\" \"${JAILDIR}/${jail_name}\"`"
	trap "rm -f \"${jail_temp}\"" SIGINT SIGQUIT SIGTERM EXIT

	lib_create_jail "${jail_temp}" "${jail_name}"

	if [ $opt_enter -eq 1 ]; then
		lib_enter_jail "${jail_name}" "${jail_user}"
	elif [ $opt_remove -eq 1 ]; then # This message is stupid if the jail will be removed.
		echo "#"
		echo "# The jail is acting as a service. If you want to enter inside it,"
		echo "# run the following command as root:"
		echo "#"
		echo "# jexec -l '${jail_name}' login -f '${jail_user}'"
		echo "#"
	fi
	
	if [ $opt_remove -eq 1 ]; then
		lib_remove_jail "${jail_temp}" "${jail_name}"
	else
		trap - SIGINT SIGQUIT SIGTERM EXIT

		echo "#"
		echo "# The jail has not been removed. If you want to remove it manually,"
		echo "# run the following command as root:"
		echo "#"
		echo "# jail -r -f '${jail_temp}' '${jail_name}' && rm -f '${jail_temp}'"
		echo "#"
	fi
}

help()
{
	usage

	echo
	echo "  -c                                  Don't run chroot(8) before create the jail."
	echo "  -l                                  Don't enter the jail after creating it."
	echo "  -r                                  Don't remove the jail after exiting it."
	echo "  -d dir                              Copy the directory to the jail environment."
	echo "                                      This directory will be an exact copy of its own tree."
	echo "                                      This flag may be used multiples times."
	echo "  -u user                             User to run inside the jail."
	echo "  -p program                          Program to run when chroot(8) is executed."
	echo "  -C path/to/appjail.conf             AppJail configuration file."
	echo "  -t path/to/some/template.conf       Template used to create the jail."
	echo "  -n jail_name                        Name of the jail."
}

usage()
{
	echo "usage: create_jail.sh [-clr] [-d dir] [-u user] [-p program] -n jail_name"
	echo "                      -t path/to/some/template.conf -C path/to/appjail.conf"
}

main $@
