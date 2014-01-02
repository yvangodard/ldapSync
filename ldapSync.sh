#!/bin/bash

#--------------------------------------------
#
#                ldapSync
#
#  Synchronize OD Group to LDAP GroupOfNames
#				 (One way)
#
#	fork of a script written by Yoann Gini
#      (VERSION 0.1 -- Dec. 15, 2010)
# 	       http://goo.gl/lVnjFw
#
#	     VERSION 0.3 -- Jan. 2, 2013
#             Licenced under
#       Creative Commons 4.0 BY NC SA
#
#           http://goo.gl/9Jgf7u
#               Yvan Godard 
#           godardyvan@gmail.com
#
#--------------------------------------------

# Variables initialisation
VERSION="ldapSync v0.3 - http://goo.gl/9Jgf7u - godardyvan@gmail.com"
help="no"
SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)
LDAP_SERVER="ldap://127.0.0.1"
LDAP_DN_BASE=""
LDAP_GROUP_DN=""
LDAP_ADMIN_UID="diradmin"
LDAP_ADMIN_PASS=""
LDAP_DN_USER_BRANCH="cn=users"
DSCL_SEARCH_PATH="/Search"
DSCL_GROUP_NAME=""
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/ldapSync.log"
LOG_ACTIVE=0
LOG_TEMP=$(mktemp /tmp/ldapSync_log.XXXXX)
ERROR_CODE_MODIFY_1=0
ERROR_CODE_MODIFY_2=0
ERROR_CODE_MODIFY_3=0
TMP_FOLDER=/tmp/ldapSync-$(uuidgen)
COMPLETE_USER_DN=${TMP_FOLDER}/all_user_dn
ACTUAL_USER_DN=${TMP_FOLDER}/actual_user_dn
ACTUAL_USER_WITH_ATTRIBUTE=${TMP_FOLDER}/actual_user_with_attribute
LDAP_ADD_LIST=${TMP_FOLDER}/ldap_add_list
LDAP_DELETE_LIST=${TMP_FOLDER}/ldap_delete_list
LDAP_ADD_MEMBEROF=${TMP_FOLDER}/ldap_add_memberof
LDAP_DELETE_MEMBEROF=${TMP_FOLDER}/ldap_delete_memberof
MEMBER_OF_GROUP=${TMP_FOLDER}/group_members
LDIF_ATTRIBUTE_MOD_FOLDER=${TMP_FOLDER}/attribute_modif
LDIF_ATTRIBUTE_MOD_LIST=${TMP_FOLDER}/attribute_modif_list_ldif
LDIF_ERROR_APPLY=${TMP_FOLDER}/error_apply_ldif
MEMBER_OF_GROUP=${TMP_FOLDER}/group_members
LDAP_MODIFY_ADD=$TMP_FOLDER/modif_add.ldif
LDAP_MODIFY_DELETE=$TMP_FOLDER/modif_delete.ldif
SYNC_MEMBEROF="no"
SYNC_MEMBEROF_ATTRIBUTE="memberOf"

help () {
	echo -e "\n**********************************************************************\n"
	echo -e "    $VERSION"
	echo -e "\n**********************************************************************\n"
	echo -e "This tool is make for sync LDAP GroupOfNames with the member list of an OD Group."
	echo -e "This tool need to be run on a computer bind to the OD."
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nSynopsis:"
	echo -e "\t./${SCRIPT_NAME} [-h] | -d <LDAP base namespace> -p <LDAP Admin password> -g <relative DN of LDAP GroupOfNames> -G <OD Groupname>"
	echo -e "\t           [-a <LDAP admin UID>] [-s <LDAP server>] [-u <relative DN of user banch>]"
	echo -e "\t           [-S <DSCL Search Path>]"
	echo -e "\t           [-e <email report option>] [-E <email address>] [-j <log file>]"
	echo -e "\n\t-h:                                      prints this help then exit"
	echo -e "\nMandatory options:"
	echo -e "\t-d <LDAP base namespace>:                the base DN for each LDAP entry (i.e.: 'dc=server,dc=office,dc=com')"
	echo -e "\t-p <LDAP admin password>:                the password of the LDAP administrator (asked if missing)"
	echo -e "\t-g <relative DN of LDAP GroupOfNames>:   the LDAP GroupOfNames to update"
	echo -e "\t-G <OD Groupname>:                       the OD group used as source"
	echo -e "\nOptional options:"
	echo -e "\t-a <LDAP admin UID>:                     UID of the LDAP administrator (i.e.: 'admin', default: '$LDAP_ADMIN_UID')"
	echo -e "\t-s <LDAP Server>:                        the LDAP server URL (default: '$LDAP_SERVER')"
	echo -e "\t-u <relative DN of user banch>:          the relative DN of the LDAP branch that contains the users (i.e.: 'cn=allusers', default: '$LDAP_DN_USER_BRANCH')"
	echo -e "\t-S <DSCL Search Path>:                   the DSCL Search path for OD Group (default: '$DSCL_SEARCH_PATH')"
	echo -e "\t-m <sync memberOf>:                      add syncing attribute of type 'memberOf' in each user LDAP entry (must be 'yes' or 'no', default: '${SYNC_MEMBEROF}'')"
	echo -e "\t-M <memberOf attribute>:                 attribute to use to add the distinguished name of the groups which the user is a member"
	echo -e "\t                                         (i.e.: 'resMemberOf', default: '${SYNC_MEMBEROF_ATTRIBUTE}'), use only if '-m' is used"           
	echo -e "\t-e <email report option>:                settings for sending a report by email, must be 'onerror', 'forcemail' or 'nomail' (default: '$EMAIL_REPORT')"
	echo -e "\t-E <email address>:                      email address to send the report, must be filled if '-e forcemail' or '-e onerror' options is used"
	echo -e "\t-j <log file>:                           enables logging instead of standard output. Specify an argument for the full path to the log file"
	echo -e "\t                                         (i.e.: '$LOG') or use 'default' ($LOG)"
	exit 0
}

error () {
	echo -e "\n*** Error ***"
	echo -e ${1}
	echo -e "\n"${VERSION}
	alldone 1
}

alldone () {
	[ $1 -ne 0 ] && echo -e "\n**** End of process with ERROR(s) ****\n" 
	[ $1 -eq 0 ] && echo -e "\n**** End of process OK : ${SCRIPT_NAME} ****\n"
	# Redirect standard outpout
	exec 1>&6 6>&-
	# Logging if needed 
	[ ${LOG_ACTIVE} -eq 1 ] && cat ${LOG_TEMP} >> ${LOG}
	# Print current log to standard outpout
	[ ${LOG_ACTIVE} -ne 1 ] && cat ${LOG_TEMP}
	[ ${EMAIL_LEVEL} -ne 0 ] && [ $1 -ne 0 ] && cat ${LOG_TEMP} | mail -s "[ERROR: ${SCRIPT_NAME}] OD Group $DSCL_GROUP_NAME to $LDAP_GROUP_DN,$LDAP_DN_BASE" ${EMAIL_ADRESS}
	[ ${EMAIL_LEVEL} -eq 2 ] && [ $1 -eq 0 ] && cat ${LOG_TEMP} | mail -s "[OK: ${SCRIPT_NAME}] OD Group $DSCL_GROUP_NAME to $LDAP_GROUP_DN,$LDAP_DN_BASE" ${EMAIL_ADRESS}
	# Remove temp files/folder
	rm -R ${LOG_TEMP}
	rm -R ${TMP_FOLDER}
	exit ${1}
}

OPTS_COUNT=0

while getopts "ha:p:g:G:s:S:d:e:E:j:u:m:M:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		a)	LDAP_ADMIN_UID=${OPTARG}
						;;
		p)	LDAP_ADMIN_PASS=${OPTARG}
                        ;;
		g)	LDAP_GROUP_DN=${OPTARG}
			let OPTS_COUNT=$OPTS_COUNT+1
                        ;;
        G)	DSCL_GROUP_NAME=${OPTARG}
			let OPTS_COUNT=$OPTS_COUNT+1
                        ;;
	    d) 	LDAP_DN_BASE=${OPTARG}
			let OPTS_COUNT=$OPTS_COUNT+1
						;;
		s)	LDAP_SERVER=${OPTARG}
                        ;;
        S)	DSCL_SEARCH_PATH=${OPTARG}
                        ;; 
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADDRESS=${OPTARG}
                        ;;
        j)	[ $OPTARG != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
        u)	LDAP_DN_USER_BRANCH=${OPTARG}
                        ;;
		m)	SYNC_MEMBEROF=${OPTARG}
                        ;;
        M)	SYNC_MEMBEROF_ATTRIBUTE=${OPTARG}
        				;;
	esac
done

if [[ ${OPTS_COUNT} != "3" ]]
then
        help
        alldone 1
fi

if [[ ${help} = "yes" ]]
then
	help
	alldone 0
fi

if [[ ${LDAP_ADMIN_PASS} = "" ]]
	then
	echo "Password for uid=$LDAP_ADMIN_UID,$LDAP_DN_USER_BRANCH,$LDAP_DN_BASE?" 
	read -s LDAP_ADMIN_PASS
fi

# Create tmp folder
mkdir -p ${TMP_FOLDER}

# Redirect standard outpout to temp file
exec 6>&1
exec >> ${LOG_TEMP}

# Begin temp log
echo -e "\n****************************** `date` ******************************\n\n$0 for $DSCL_GROUP_NAME to $LDAP_GROUP_DN,$LDAP_DN_BASE\n"

# Test of sending email parameter and check the consistency of the parameter email address
if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z ${EMAIL_ADDRESS} ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
    		echo -e "This address '${EMAIL_REPORT}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z ${EMAIL_ADDRESS} ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
    		echo -e "This address '${EMAIL_REPORT}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo -e "\nOption '-e ${EMAIL_REPORT}' is not valid (must be: 'onerror', 'forcemail' or 'nomail').\n\t-> We continue the process without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

# Test ${SYNC_MEMBEROF}
[[ ${SYNC_MEMBEROF} != "yes" ]] && [[ ${SYNC_MEMBEROF} != "no" ]] && error "Trying to use '-m' option but paramter '${SYNC_MEMBEROF}' is forbiden, must be 'yes' or 'no'."


echo -e "\n**********************************************************************"
echo -e "               Group OpenDirectory -> LDAP GroupOfNames"
echo -e "**********************************************************************\n"

# LDAP connection test...
echo -e "Test to bind LDAP ${LDAP_SERVER}:"
ldapsearch -LLL -x -b ${LDAP_GROUP_DN},${LDAP_DN_BASE} -H ${LDAP_SERVER} > /dev/null 2>&1
if [ $? -ne 0 ]
	then 
	error "Error while connecting with LDAP ${LDAP_SERVER} (${LDAP_GROUP_DN},${LDAP_DN_BASE}).\nPlease verify LDAP connection parameters, base DN and group relative DN."
else
	echo -e "-> OK"
fi

# Test if OD group exists and if OD group contains members
echo -e "\nCommand: '${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership'"
dscl ${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership > /dev/null 2>&1
if [ $? -ne 0 ] 
	then
		error "Command 'dscl ${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership' did not work properly.\nError $?."
	else
		dscl ${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership > ${MEMBER_OF_GROUP}
		[[ -z $(cat ${MEMBER_OF_GROUP}) ]] && error "Command 'dscl ${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership' does not find any user in the group."
fi

# Export actual members of OD group
echo -e "Actual members of OD group:"
dscl ${DSCL_SEARCH_PATH} read /Groups/${DSCL_GROUP_NAME} GroupMembership | sed 's/GroupMembership: //g' | tr ' ' '\n' | xargs -I @ echo @ | while read LINE_UID
do
	echo uid=${LINE_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} >> ${COMPLETE_USER_DN}
	echo -e "\t- ${LINE_UID} (uid=${LINE_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE})"
done

# Export actual members of groupOfNames group
ldapsearch -LLL -x -b ${LDAP_GROUP_DN},${LDAP_DN_BASE} -H ${LDAP_SERVER} | grep member | awk '{print $2}' >> ${ACTUAL_USER_DN}

# Calculation of changes to be applied
grep -vf ${ACTUAL_USER_DN} ${COMPLETE_USER_DN} > ${LDAP_ADD_LIST}
grep -vf ${COMPLETE_USER_DN} ${ACTUAL_USER_DN} > ${LDAP_DELETE_LIST}

# Nothing to change
[[ -z $(cat ${LDAP_DELETE_LIST}) ]] &&  [[ -z $(cat ${LDAP_ADD_LIST}) ]] && echo -e "-> Nothing to sync at this step!"

# Delete users in groupOfNames
if [[ ! -z $(cat ${LDAP_DELETE_LIST}) ]]
	then
	echo "dn: ${LDAP_GROUP_DN},${LDAP_DN_BASE}" > ${LDAP_MODIFY_DELETE}
	echo "changetype: modify" >> ${LDAP_MODIFY_DELETE}
	echo "delete: member" >> ${LDAP_MODIFY_DELETE}
	for MEMBER in $(cat ${LDAP_DELETE_LIST})
	do 
		echo "${MEMBER}" | sed 's/uid=/member: uid=/' >> ${LDAP_MODIFY_DELETE}
	done
	echo -e "\n...Delete users on ${LDAP_SERVER} on groupOfNames ${LDAP_GROUP_DN},${LDAP_DN_BASE}:"
	ldapmodify -D uid=${LDAP_ADMIN_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} -w ${LDAP_ADMIN_PASS} -H ${LDAP_SERVER} -x -f ${LDAP_MODIFY_DELETE}
	[ $? -ne 0 ] && ERROR_CODE_MODIFY_1=1
	OLDIFS=$IFS
	IFS=$'\n'
	for MODIF_LINE in $(cat ${LDAP_MODIFY_DELETE})
	do
		echo -e "\t${MODIF_LINE}"
	done
	IFS=$OLDIFS
fi

# Add users to groupOfNames
if [[ ! -z $(cat ${LDAP_ADD_LIST}) ]]
	then
	echo "dn: ${LDAP_GROUP_DN},${LDAP_DN_BASE}" > ${LDAP_MODIFY_ADD}
	echo "changetype: modify" >> ${LDAP_MODIFY_ADD}
	echo "add: member" >> ${LDAP_MODIFY_ADD}
	for MEMBER in $(cat ${LDAP_ADD_LIST})
	do 
		echo "${MEMBER}" | sed 's/uid=/member: uid=/' >> ${LDAP_MODIFY_ADD}
	done
	echo -e "\n...Add users on ${LDAP_SERVER} on groupOfNames ${LDAP_GROUP_DN},${LDAP_DN_BASE}:"
	ldapmodify -D uid=${LDAP_ADMIN_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} -w ${LDAP_ADMIN_PASS} -H ${LDAP_SERVER} -x -f ${LDAP_MODIFY_ADD}
	[ $? -ne 0 ] && ERROR_CODE_MODIFY_2=1
	OLDIFS=$IFS
	IFS=$'\n'
	for MODIF_LINE in $(cat ${LDAP_MODIFY_ADD})
	do
		echo -e "\t${MODIF_LINE}"
	done
	IFS=$OLDIFS
fi

# Processing error code
if [ ${ERROR_CODE_MODIFY_1} -ne 0 ] || [ ${ERROR_CODE_MODIFY_2} -ne 0 ]
	then
	error "Error while applying LDAP groupOfNames modifications on ${LDAP_SERVER}.\nPlease verify LDAP connection parameters and result."
fi

# Modifications on user attribute
if [[ ${SYNC_MEMBEROF} = "yes" ]]
	then
	echo -e "\n**********************************************************************"
	echo -e "               Add or delete attribute ${SYNC_MEMBEROF_ATTRIBUTE}"
	echo -e "**********************************************************************\n"

	mkdir -p ${LDIF_ATTRIBUTE_MOD_FOLDER}

	# Export actual user with attribute ${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}
	ldapsearch -LLL -x -H ${LDAP_SERVER} -D uid=${LDAP_ADMIN_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} -w ${LDAP_ADMIN_PASS} -b ${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} ${SYNC_MEMBEROF_ATTRIBUTE}=${LDAP_GROUP_DN},${LDAP_DN_BASE} | grep uid= | sed 's/dn: //' >> ${ACTUAL_USER_WITH_ATTRIBUTE}
	
	# Calculation of changes to be applied on users
	grep -vf ${ACTUAL_USER_WITH_ATTRIBUTE} ${COMPLETE_USER_DN} > ${LDAP_ADD_MEMBEROF}
	grep -vf ${COMPLETE_USER_DN} ${ACTUAL_USER_WITH_ATTRIBUTE} > ${LDAP_DELETE_MEMBEROF}
	
	echo -e "Add or delete attribute '${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}' to users on ${LDAP_SERVER}"
	
	[[ -z $(cat ${LDAP_ADD_MEMBEROF}) ]] && [[ -z $(cat ${LDAP_DELETE_MEMBEROF}) ]] && echo -e "-> Nothing to sync at this step!" && alldone 0

	# Add attribute ${SYNC_MEMBEROF_ATTRIBUTE} to users
	if [[ ! -z $(cat ${LDAP_ADD_MEMBEROF}) ]]
		then
		for USER_DN in $(cat ${LDAP_ADD_MEMBEROF})
		do
			USER_UID=$(echo ${USER_DN} | awk -F'=' '{print $2}' | awk -F',' '{print $1}')
			# Opening LDIF file
			LDIF_FILE=${LDIF_ATTRIBUTE_MOD_FOLDER}/${USER_UID}.ldif
			echo "dn: ${USER_DN}" > ${LDIF_FILE}
			echo "changetype: modify" >> ${LDIF_FILE}
			echo "add: ${SYNC_MEMBEROF_ATTRIBUTE}" >> ${LDIF_FILE}
			echo "${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}" >> ${LDIF_FILE}
			echo -e "...Add: '${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}' to '${USER_DN}'"
		done
	fi

	# Delete attribute ${SYNC_MEMBEROF_ATTRIBUTE} to users
	if [[ ! -z $(cat ${LDAP_DELETE_MEMBEROF}) ]]
		then
		for USER_DN in $(cat ${LDAP_DELETE_MEMBEROF})
		do
			USER_UID=$(echo ${USER_DN} | awk -F'=' '{print $2}' | awk -F',' '{print $1}')
			# Opening LDIF file
			LDIF_FILE=${LDIF_ATTRIBUTE_MOD_FOLDER}/${USER_UID}.ldif
			echo "dn: ${USER_DN}" > ${LDIF_FILE}
			echo "changetype: modify" >> ${LDIF_FILE}
			echo "delete: ${SYNC_MEMBEROF_ATTRIBUTE}" >> ${LDIF_FILE}
			echo "${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}" >> ${LDIF_FILE}
			echo -e "...Delete: '${SYNC_MEMBEROF_ATTRIBUTE}: ${LDAP_GROUP_DN},${LDAP_DN_BASE}' to '${USER_DN}'"
		done
	fi

	# Processing 
	find ${LDIF_ATTRIBUTE_MOD_FOLDER} -type f -name "*.ldif" >> ${LDIF_ATTRIBUTE_MOD_LIST}
	if [[ ! -z $(cat ${LDIF_ATTRIBUTE_MOD_LIST}) ]]
		then
		for LDIF_MODIF_FILE in $(cat ${LDIF_ATTRIBUTE_MOD_LIST})
		do
			ldapmodify -D uid=${LDAP_ADMIN_UID},${LDAP_DN_USER_BRANCH},${LDAP_DN_BASE} -w ${LDAP_ADMIN_PASS} -H ${LDAP_SERVER} -x -f ${LDIF_MODIF_FILE}
			if [ $? -ne 0 ] 
				then
				ERROR_CODE_MODIFY_3=1
				echo $(basename ${LDIF_MODIF_FILE}) | sed 's/.ldif//' >> ${LDIF_ERROR_APPLY}
			fi
		done
	fi

	# Processing error code
	if [ ${ERROR_CODE_MODIFY_3} -ne 0 ]
		then
		error "Error while applying LDAP modifications on ${LDAP_SERVER} for users:\n$(cat ${LDIF_ERROR_APPLY} | perl -p -e 's/\n/ - /g' | awk 'sub( "...$", "" )')\nPlease verify LDAP connection parameters and result for these users."
	fi

	echo -e "-> OK"
fi

alldone 0