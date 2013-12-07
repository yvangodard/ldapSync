#!/bin/bash

#--------------------------------------------
#
#                ldapSync
#
#  Synchronize OD Group to LDAP GroupOfNames
#				 (One way)
#
#	   fork d'un script de Yoann Gini
#      (Version 0.1 -- Dec. 15, 2010)
# 	       http://goo.gl/lVnjFw
#
#	   Version 0.2 -- 7 décembre 2013
#           Soumis à la licence 
#       Creative Commons 4.0 BY NC SA
#
#          http://goo.gl/9Jgf7u
#              Yvan Godard 
#          godardyvan@gmail.com
#
#--------------------------------------------

version="ldapSync v0.2 - http://goo.gl/9Jgf7u - godardyvan@gmail.com"
help="no"

ldapServer="ldap://127.0.0.1"
ldapDN=""
ldapGroupDN=""
ldapAdminDN=""
ldapAdminPswd=""
dsclSearchPath="/Search"
dsclGroupName=""
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/ldapSync.log"
LOG_ACTIVE=0
LOG_TEMP=$(mktemp /tmp/ldapSync_log.XXXXX)
ERROR_CODE_MODIFY=0

help () {
	echo -e "$version\n"
	echo -e "This tool is make for sync LDAP GroupOfNames with the member list of an OD Group."
	echo -e "This tool need to be run on a computer bind to the OD."
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nUsage:"
	echo -e "\tldapSync [-h] | -d <LDAP base namespace> -a <relative DN of LDAP admin> -p <LDAP Admin password> -g <relative DN of LDAP GroupOfNames> -G <OD Groupname>"
	echo -e "with:"
	echo -e "\t-h:                                      prints this help then exit"
	echo -e "\t-d <LDAP base namespace>:                the base DN for each LDAP entry (i.e.: dc=office,dc=acme,dc=com)"
	echo -e "\t-a <retlative DN of LDAP admin>:         the reltaive DN of the LDAP administrator (i.e.: uid=diradmin,cn=users)"
	echo -e "\t-p <LDAP Admin password>:                the password of the LDAP administrator (Asked if missing)"
	echo -e "\t-g <reltaive DN of LDAP GroupOfNames>:   the LDAP GroupOfNames to update"
	echo -e "\t-G <OD Groupname>:                       the OD group used as source"
	echo -e "\t-s <LDAP Server>:                        the LDAP server URL [$ldapServer]"
	echo -e "\t-S <DSCL Search Path>:                   the DSCL Search path for OD Group [$dsclSearchPath]"
	echo -e "\t-e <Option rapport email> :              settings for sending a report by email: [$EMAIL_REPORT] (i.e.: onerror|forcemail|nomail)"
	echo -e "\t-E <Adresse email> :                     valid addresss to send the email report (parameter is required if -e forcemail ou -e onerror)"
	echo -e "\t-j <Fichier Log> :                       enables logging instead of standard output. Argument specify the full path to the log file [$LOG] or 'default' for $LOG"
	exit 0
}

error () {
	rm -rf $tmpFolder
	echo -e "\n"${version}
	echo -e "*** Error:"
	echo -e "\t"${1}
	alldone 1
}

alldone () {
	[ $1 -ne 0 ] && echo -e "\n**** End of process with ERROR(s) ****\n" 
	[ $1 -eq 0 ] && echo -e "\n**** End of process OK : $0 ****\n"
	exec 1>&6 6>&-
	# Journalisation si besoin
	[ $LOG_ACTIVE -eq 1 ] && cat $LOG_TEMP >> $LOG
	# Renvoi du journal courant vers la sortie standard
	[ $LOG_ACTIVE -ne 1 ] && cat $LOG_TEMP
	[ $EMAIL_LEVEL -ne 0 ] && [ $1 -ne 0 ] && cat $LOG_TEMP | mail -s "[ERROR : ldapSync.sh] OD Group $dsclGroupName to $ldapGroupDN,$ldapDN" ${EMAIL_ADRESSE}
	[ $EMAIL_LEVEL -eq 2 ] && [ $1 -eq 0 ] && cat $LOG_TEMP | mail -s "[OK : ldapSync.sh] OD Group $dsclGroupName to $ldapGroupDN,$ldapDN" ${EMAIL_ADRESSE}
	rm $LOG_TEMP
	exit ${1}
}

optsCount=0

while getopts "ha:p:g:G:s:S:d:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		a)	ldapAdminDN=${OPTARG}
			let optsCount=$optsCount+1
						;;
		p)	ldapAdminPswd=${OPTARG}
                        ;;
		g)	ldapGroupDN=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
        G)	dsclGroupName=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
	    d) 	ldapDN=${OPTARG}
			let optsCount=$optsCount+1
						;;
		s)	ldapServer=${OPTARG}
                        ;;
        S)	dsclSearchPath=${OPTARG}
                        ;; 
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADRESSE=${OPTARG}
                        ;;
        j)	[ $OPTARG != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
	esac
done

if [[ ${optsCount} != "4" ]]
then
        help
        alldone 1
fi

if [[ ${help} = "yes" ]]
then
	help
	alldone 0
fi

if [[ ${ldapAdminPswd} = "" ]]
then
	echo "Password for $ldapAdminDN,$ldapDN:" 
	read -s ldapAdminPswd
fi

# Redirection de la sortie vers un fichier temporaire
exec 6>&1
exec >> $LOG_TEMP

# Ouverture du log temporaire
echo -e "\n****************************** `date` ******************************\n\n$0 for $dsclGroupName to $ldapGroupDN,$ldapDN\n"

# Test du paramètre d'envoi d'email et vérification de la cohérence de l'adresse email
if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADRESSE ]]
		then
		echo -e "For use with -e $EMAIL_REPORT, need an adress (-E <email@address.com>).\n\t-> The process will continue without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADRESSE}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
    		echo -e "This email address : $EMAIL_ADRESSE seems to be incorrect.\n\t-> The process will continue without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADRESSE ]]
		then
		echo -e "For use with -e $EMAIL_REPORT, need an adress (-E <email@address.com>).\n\t-> The process will continue without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADRESSE}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
    		echo -e "This email address : $EMAIL_ADRESSE seems to be incorrect.\n\t-> The process will continue without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo -e "Invalid parameter -e $EMAIL_REPORT (must be : onerror|forcemail|nomail).\n\t-> The process will continue without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

tmpFolder=/tmp/ldapSync-$(uuidgen)
completeUsersDN=$tmpFolder/allUsersDN
actualUsersDN=$tmpFolder/actualUsersDN
ldapModify=$tmpFolder/modif.ldif
ldapAdd=$tmpFolder/add
ldapDelete=$tmpFolder/delete
hasChange="no"

mkdir -p $tmpFolder

# Vérification de la présence du groupe OD et d'utilisateurs dans le groupe
echo -e "\nCommand: '$dsclSearchPath read /Groups/$dsclGroupName GroupMembership'"
dscl $dsclSearchPath read /Groups/$dsclGroupName GroupMembership > /dev/null 2>&1
if [ $? -ne 0 ] 
	then
		error "Command 'dscl $dsclSearchPath read /Groups/$dsclGroupName GroupMembership' did not work properly.\nError $?."
	else
		MembersOfGroup=$(mktemp /tmp/ldapSync.XXXXX)
		dscl $dsclSearchPath read /Groups/$dsclGroupName GroupMembership > $MembersOfGroup
		if [[ -z $(cat $MembersOfGroup) ]] 
			then 
			rm $MembersOfGroup
			error "Command 'dscl $dsclSearchPath read /Groups/$dsclGroupName GroupMembership' does not find any user in the group."
		fi
		rm $MembersOfGroup
	fi

echo -e "Actual members on OD group:"
dscl $dsclSearchPath read /Groups/$dsclGroupName GroupMembership | sed 's/GroupMembership: //g' | tr ' ' '\n' | xargs -I @ echo @ | while read line
do
	echo uid=$line,cn=users,$ldapDN >> $completeUsersDN
	echo -e "\t- $line (uid=$line,cn=users,$ldapDN)"
done

# Test de la connexion au LDAP
echo -e "\nTest to bind LDAP $ldapServer:"
ldapsearch -LLL -x -b $ldapGroupDN,$ldapDN -H $ldapServer > /dev/null 2>&1
if [ $? -ne 0 ]
	then 
	error "Error while connecting with LDAP $ldapServer ($ldapGroupDN,$ldapDN).\nPlease verify LDAP connection parameters, base DN and group relative DN."
else
	echo -e "\t-> OK"
fi

ldapsearch -LLL -x -b $ldapGroupDN,$ldapDN -H $ldapServer | grep member | awk '{print $2}' >> $actualUsersDN

grep -vf $actualUsersDN $completeUsersDN | sed 's/uid=/member: uid=/' > $ldapAdd
grep -vf $completeUsersDN $actualUsersDN | sed 's/uid=/member: uid=/' > $ldapDelete

echo "dn: $ldapGroupDN,$ldapDN" > $ldapModify
echo "changetype: modify" >> $ldapModify

if [[ $(wc $ldapAdd | awk '{print $1}') != 0 ]]
then
	echo "add: member" >> $ldapModify
	cat $ldapAdd >> $ldapModify
	hasChange="yes"
fi

if [[ $(wc $ldapDelete | awk '{print $1}') != 0 ]]
then
	echo "delete: member" >> $ldapModify
    cat $ldapDelete >> $ldapModify
	hasChange="yes"
fi

# Pas de changement à effectuer
if [[ ${hasChange} = "no" ]]
then
    rm -rf $tmpFolder
	echo -e "\n***************\nNothing to sync\n***************"
    alldone 0
fi

echo -e "\n...Applying modifications on $ldapServer:"
# Application des modifications sur la branche groupOfNames du LDAP
ldapmodify -D $ldapAdminDN,$ldapDN  -w $ldapAdminPswd -H $ldapServer -x -f $ldapModify
[ $? -ne 0 ] && ERROR_CODE_MODIFY=1

OLDIFS=$IFS
IFS=$'\n'
for MODIF_LINE in $(cat ${ldapModify})
do
	echo -e "\t ... ${MODIF_LINE}"
done
IFS=$OLDIFS

# Traitement du message d'erreur
[ $ERROR_CODE_MODIFY -ne 0 ] && error "Error while modifying LDAP $ldapServer.\nPlease verify LDAP connection parameters and result."

rm -rf $tmpFolder

alldone 0