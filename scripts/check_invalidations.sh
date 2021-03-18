#!/usr/bin/env bash

# Modified from https://github.com/swoodford/aws/blob/master/cloudfront-invalidation-status.sh
# Cloudfront ID is known ahead of time, but script can still handle multiple concurrent invalidations on the same distribution

# This script monitors CloudFront distributions for cache invalidation status and alerts when it has completed
# Requires the AWS CLI and jq

# Functions

# Check Command
function check_command {
	type -P $1 &>/dev/null || fail "Unable to find $1, please install it and run this script again."
}

# Completed
function completed(){
	echo
	HorizontalRule
	echo "Exiting Script!"
	HorizontalRule
	echo
	exit 0
}

# Fail
function fail(){
	echo "Failure: $*"
	exit 1
}

# Horizontal Rule
function HorizontalRule(){
	echo "============================================================"
}

# List Invalidations
function listInvalidations(){
	HorizontalRule
	echo "Checking for Invalidations In Progress..."

	invalidations=$(aws cloudfront list-invalidations --distribution-id $CLOUDFRONT_DIST_ID | jq '.InvalidationList | .Items | .[] | select(.Status != "Completed") | .Id' | cut -d \" -f2)
	if ! [ -z "$invalidations" ]; then
		HorizontalRule
		echo "Invalidation in progress: $invalidations"
		HorizontalRule
	fi
}

# Check the Invalidation Status
function checkInvalidationstatus(){
	if [ -z "$invalidations" ]; then
		echo No CloudFront Invalidations In Progress.
		HorizontalRule
		completed
	else
		while IFS= read -r invalidationid
		do
			invalidationStatus=$(aws cloudfront get-invalidation --distribution-id $CLOUDFRONT_DIST_ID --id $invalidationid | jq '.Invalidation | .Status' | cut -d \" -f2)

			while [ $invalidationStatus = "InProgress" ]; do
				HorizontalRule
				echo "Invalidation ID: $invalidationid" 
				echo "Status: $invalidationStatus"
				echo "Waiting for invalidation to complete..."
				HorizontalRule
				sleep 10
				checkInvalidationstatus
				if [ $invalidationStatus = "Completed" ]; then
					echo "CloudFront Invalidation $invalidationStatus"
					break
				fi
			done	
		done
		completed
	fi
}

check_command "jq"
listInvalidations
checkInvalidationstatus
