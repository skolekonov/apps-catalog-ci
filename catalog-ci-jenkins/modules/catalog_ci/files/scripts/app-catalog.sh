#!/bin/bash -x

WDIR=$JENKINS_HOME/scripts
PATCH=$GERRIT_CHANGE_NUMBER
CODES=(100 200 302)
TMP_DIR=$(mktemp -d)
TMP_FILE=$(mktemp)
EVENT=$GERRIT_EVENT_TYPE
FILE_LIST=$(git diff HEAD~1 --name-only)
IMAGE_CONFIG="openstack_catalog/web/static/glance_images.yaml"
IMAGE_CDN_PATH="catalog_ci:catalog/images"

clean() {
    rm -rf $TMP_DIR
    rm -f  $TMP_FILE
}

upload_image () {
    local CONFIG
    local OLD_CONFIG
    local IMAGE_NAME
    local IMAGE_PATH

    IMAGE_PATH=$1
    CONFIG=$TMP_DIR/$(basename $IMAGE_CONFIG)
    OLD_CONFIG=$TMP_DIR/$(basename $IMAGE_CONFIG).old
    IMAGE_NAME=$(python $WDIR/generate_names.py glance $OLD_CONFIG $CONFIG)

    echo "Uploading image $IMAGE_NAME from $IMAGE_PATH"
    mv $IMAGE_PATH $(dirname $IMAGE_PATH)/$IMAGE_NAME
    rclone copy $(dirname $IMAGE_PATH)/$IMAGE_NAME $IMAGE_CDN_PATH
    clean
}

main() {
    local URL
    local HASH
    local REAL_HASH
    local HTTP_CODE
    local IMAGE

    ssh -p 29418 catalog-ci@review.openstack.org gerrit query $PATCH > $TMP_FILE
    URL=$(cat $TMP_FILE | egrep "^\s*Image-URL:\s(https?|ftp)://.*" | egrep -o "(https?|ftp)://.*$")
    HASH=$(cat $TMP_FILE | egrep "^\s*Image-hash:\s[A-Za-z0-9]*$" | egrep -o "[A-Za-z0-9]*$")

    cat $TMP_FILE | grep  Image-URL | grep -q Unknown && exit 0

    if [ -z $URL -o -z $HASH ]; then
      echo "Image URL or hash wasn't found"
      clean
      exit 1
    else
      HTTP_CODE=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' $URL)
      if ! [[ " ${CODES[*]} " == *" $HTTP_CODE "* ]]; then
        echo "File wasn't found"
        clean
        exit 1
      fi
    fi


    if [ "$HASH" == "Unknown" ]; then
      echo "Image hash is unknown, skipping checks..."
    else
      wget $URL -P $TMP_DIR
      REAL_HASH=$(md5sum $TMP_DIR/* | awk '{print $1}')
      if [ "$REAL_HASH" != "$HASH" ]; then
        echo "Hash mismatch"
        clean
        exit 1
      else
        echo "Image hash is correct"
      fi
    fi

    if [ "$EVENT" == "change-merged" ]; then
      IMAGE=$(ls $TMP_DIR/*)
      cp $IMAGE_CONFIG $TMP_DIR
      git checkout $GERRIT_BRANCH
      git pull
      cp $IMAGE_CONFIG $TMP_DIR/$(basename $IMAGE_CONFIG).old
      upload_image $IMAGE
   else
     clean
   fi
}

if [[ ${FILE_LIST[*]} =~ "$IMAGE_CONFIG" ]]; then
  main "$@"
fi
