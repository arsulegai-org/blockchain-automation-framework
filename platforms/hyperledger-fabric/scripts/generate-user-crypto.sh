#!/bin/bash
if [ $# -lt 6 ]; then
	echo "Usage : . $0 orderer|peer <namespace> <nodename> <no of users: min 1>|<user-identity> <affiliation> <subject>"
	exit
fi

set -x

# Input parameters
FULLY_QUALIFIED_ORG_NAME=$2
ORG_NAME=$3
TYPE_FOLDER=$1s
NUM_OR_USER_IDENTITY=$4
AFFILIATION=$5
SUBJECT=$6

# Local variables
CURRENT_DIR=${PWD}

CA="ca.${FULLY_QUALIFIED_ORG_NAME}:7054"

if [ "$1" != "peer" ]; then
	ORG_CYPTO_FOLDER="/crypto-config/ordererOrganizations/${FULLY_QUALIFIED_ORG_NAME}"
	ROOT_TLS_CERT="/crypto-config/ordererOrganizations/${FULLY_QUALIFIED_ORG_NAME}/ca/ca.${FULLY_QUALIFIED_ORG_NAME}-cert.pem"
else
	ORG_CYPTO_FOLDER="/crypto-config/$1Organizations/${FULLY_QUALIFIED_ORG_NAME}"
	ROOT_TLS_CERT="/crypto-config/$1Organizations/${FULLY_QUALIFIED_ORG_NAME}/ca/ca.${FULLY_QUALIFIED_ORG_NAME}-cert.pem"
fi

CAS_FOLDER="${HOME}/ca-tools/cas/ca-${ORG_NAME}"
ORG_HOME="${HOME}/ca-tools/${ORG_NAME}"

NUMBERS='^[0-9]+$'
TOTAL_USERS=1
CUSTOM_IDENTITY="true"
if [[ ${NUM_OR_USER_IDENTITY} =~ ${NUMBERS} ]]; then
  TOTAL_USERS=${NUM_OR_USER_IDENTITY}
  CUSTOM_IDENTITY="false"
fi

## Register and enroll users
CUR_USER=0
while [ ${CUR_USER} -lt ${TOTAL_USERS} ]; do
	## increment value first to avoid User0
	CUR_USER=$((CUR_USER + 1))

	# Get the user identity
	if [[ "${CUSTOM_IDENTITY}" == "true" ]]; then
	  USER="${NUM_OR_USER_IDENTITY}"
	else
	  USER=USER+${CUR_USER}
	fi

	## Register and enroll User for Org
	ORG_USER="User${USER}@${FULLY_QUALIFIED_ORG_NAME}"
	ORG_USERPASS="User${USER}@${FULLY_QUALIFIED_ORG_NAME}-pw"

	if [ "$1" = "peer" ]; then
		fabric-ca-client register -d --id.name ${ORG_USER} --id.secret ${ORG_USERPASS} --id.type user --csr.names "${SUBJECT}" --id.affiliation ${AFFILIATION} --id.attrs "hf.Revoker=true" --tls.certfiles ${ROOT_TLS_CERT} --home ${CAS_FOLDER}
	else
		fabric-ca-client register -d --id.name ${ORG_USER} --id.secret ${ORG_USERPASS} --id.type user --csr.names "${SUBJECT}" --id.attrs "hf.Revoker=true" --tls.certfiles ${ROOT_TLS_CERT} --home ${CAS_FOLDER}
	fi

	fabric-ca-client enroll -d -u https://${ORG_USER}:${ORG_USERPASS}@${CA} --csr.names "${SUBJECT}" --tls.certfiles ${ROOT_TLS_CERT} --home ${ORG_HOME}/client${USER}

	mkdir ${ORG_HOME}/client${USER}/msp/admincerts
	cp ${ORG_HOME}/client${USER}/msp/signcerts/* ${ORG_HOME}/client${USER}/msp/admincerts/${ORG_USER}-cert.pem

	mkdir -p ${ORG_CYPTO_FOLDER}/users/${ORG_USER}
	cp -R ${ORG_HOME}/client${USER}/msp ${ORG_CYPTO_FOLDER}/users/${ORG_USER}

	# Get TLS cert for user and copy to appropriate location
	fabric-ca-client enroll -d --enrollment.profile tls -u https://${ORG_USER}:${ORG_USERPASS}@${CA} -M ${ORG_HOME}/client${USER}/tls --tls.certfiles ${ROOT_TLS_CERT}

	# Copy the TLS key and cert to the appropriate place
	mkdir -p ${ORG_CYPTO_FOLDER}/users/${ORG_USER}/tls
	cp ${ORG_HOME}/client${USER}/tls/keystore/* ${ORG_CYPTO_FOLDER}/users/${ORG_USER}/tls/client.key
	cp ${ORG_HOME}/client${USER}/tls/signcerts/* ${ORG_CYPTO_FOLDER}/users/${ORG_USER}/tls/client.crt
	cp ${ORG_HOME}/client${USER}/tls/tlscacerts/* ${ORG_CYPTO_FOLDER}/users/${ORG_USER}/tls/ca.crt
done
cd ${CURRENT_DIR}
