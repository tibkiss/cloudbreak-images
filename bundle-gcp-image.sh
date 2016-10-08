#!/bin/bash

set -eo pipefail
set -x

: ${START_TIME:=$(date +%s)}
export START_TIME
export PS4='+ [TRACE $BASH_SOURCE:$LINENO][ellapsed: $(( $(date +%s) -  $START_TIME ))] '

: ${DEBUG:=1}

debug() {
    [[ "$DEBUG" ]] && echo "-----> $*" 1>&2
}

main() {
	if [[ -z "$IMAGE_NAME" ]]; then
		IMAGE_NAME=$(curl https://atlas.hashicorp.com/api/v1/artifacts/sequenceiq/cloudbreak/googlecompute.image/search | jq '.versions[0].metadata.image_name' -r)
	fi

	: ${ZONE:=us-central1-b}
	: ${INSTANCE_NAME:=$IMAGE_NAME}
	: ${TEMP_DISK_NAME:=${IMAGE_NAME//-}disk}
	: ${PROJECT:=}
	: ${GCP_ACCOUNT_FILE:=}
	: ${SERVICE_ACCOUNT_EMAIL:=$(cat $GCP_ACCOUNT_FILE | jq .client_email -r)}	

    docker run --name gcloud-config-$IMAGE_NAME -v "${GCP_ACCOUNT_FILE}":/gcp.p12 google/cloud-sdk gcloud auth activate-service-account $SERVICE_ACCOUNT_EMAIL --key-file /gcp.p12 --project $PROJECT
	docker run --rm --name gcloud-create-instance-$IMAGE_NAME --volumes-from gcloud-config-$IMAGE_NAME google/cloud-sdk gcloud compute instances create $INSTANCE_NAME --image centos-7-v20160921 --machine-type n1-standard-2 --zone $ZONE --boot-disk-size 200GB --image-project centos-cloud --scopes $SERVICE_ACCOUNT_EMAIL=storage-full,$SERVICE_ACCOUNT_EMAIL=compute-rw,$SERVICE_ACCOUNT_EMAIL=cloud-platform --metadata startup-script='#! /bin/bash
cat>/opt/img.sh<<"EOF"
set -x
curl -o /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq && chmod +x /usr/bin/jq
echo Started: $(date) >> /var/log/image.log
while [[ ! -e /dev/sdb ]]; do echo $(date) waiting for disk >> /var/log/image.log; sleep 1; done
echo Create TAR: $(date) >> /var/log/image.log
mkdir -p /mnt/packer 
mount /dev/sdb1 /mnt/packer/ -t xfs -o nouuid
mkdir -p /home/centos/image
dd if=/dev/sdb of=/home/centos/image/disk.raw bs=4096
tar czvf /home/centos/image/myimage.tar.gz /home/centos/image/disk.raw
HOSTNAME=$(hostname)
gsutil cp -a public-read /home/centos/image/myimage.tar.gz gs://sequenceiqimage/$HOSTNAME.tar.gz
echo Ended: $(date) >> /var/log/image.log
echo Cleanup: $(date) >> /var/log/image.log
umount /mnt/packer
ZONE_PROJECT=$(curl 169.254.169.254/0.1/meta-data/zone)
ZONE=${ZONE_PROJECT##*/}
gcloud compute instances detach-disk $HOSTNAME --disk ${HOSTNAME//-}disk --zone $ZONE
gcloud compute disks delete ${HOSTNAME//-}disk --zone $ZONE -q
gcloud compute instances delete $HOSTNAME --zone $ZONE -q
EOF
chmod +x /opt/img.sh
nohup /opt/img.sh &'
	docker run --rm --name gcloud-create-disk-$IMAGE_NAME --volumes-from gcloud-config-$IMAGE_NAME google/cloud-sdk gcloud compute disks create $TEMP_DISK_NAME --image $IMAGE_NAME --zone $ZONE
	docker run --rm --name gcloud-attach-disk-$IMAGE_NAME --volumes-from gcloud-config-$IMAGE_NAME google/cloud-sdk gcloud compute instances attach-disk $INSTANCE_NAME --disk $TEMP_DISK_NAME --zone $ZONE
	while ! docker run --rm --name gcloud-wait-$IMAGE_NAME --volumes-from gcloud-config-$IMAGE_NAME google/cloud-sdk gsutil ls gs://sequenceiqimage/${IMAGE_NAME}.tar.gz 2>/dev/null; do echo waiting for tar: ${IMAGE_NAME}.tar.gz; sleep 10; done
	docker rm gcloud-config-$IMAGE_NAME

}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"