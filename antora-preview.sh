#!/bin/sh

ANTORA_PATH=$1
FILE=/antora/$ANTORA_PATH/antora.yml

cd /antora
if test -f "$FILE"; then
    # Read component name from antora.yml
    COMPONENT=$(yq r /antora/$ANTORA_PATH/antora.yml 'name')
    yq w --inplace /playbook.yml 'site.start_page' $COMPONENT::index.adoc
    yq w --inplace /playbook.yml 'content.sources[0].start_path' $ANTORA_PATH
    antora /playbook.yml
    cd /public
    cp /Caddyfile /public/Caddyfile
    caddy run
else
    echo "$FILE does not exist"
fi

