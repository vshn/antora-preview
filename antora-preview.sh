#!/bin/sh

for i in "$@"
do
case $i in
    -s=*|--style=*)
    ANTORA_STYLE="${i#*=}"

    ;;
    -a=*|--antora=*)
    ANTORA_PATH="${i#*=}"
    ;;
    *)
        echo "Antora Documentation Previewer"
        echo ""
        echo "This command builds an Antora documentation website locally"
        echo "and launches a web server on port 2020 to browse the documentation."
        echo ""
        echo "Arguments:"
        echo "    --style=STYLE / -s=STYLE:"
        echo "           Antora UI Bundle to use to render the documentation."
        echo "           Valid values: 'vshn', 'appuio', 'syn'."
        echo "           Default value: 'vshn'"
        echo ""
        echo "    -a=PATH / --antora=PATH:"
        echo "           Path to the subfolder."
        echo "           Default: 'docs'"
        echo ""
        echo "Examples:"
        echo "    antora-preview --style=appuio --antora=src"
        echo ""
        exit 0
    ;;
esac
done

ANTORA_STYLE=${ANTORA_STYLE:-vshn}
ANTORA_PATH=${ANTORA_PATH:-docs}

cd /antora || exit
ANTORA_FILE=/antora/$ANTORA_PATH/antora.yml
if [ ! -f "$ANTORA_FILE" ]; then
	echo "Cannot find Antora file '$ANTORA_FILE'"
	exit 1
fi

ANTORA_BUNDLE=/preview/bundle.$ANTORA_STYLE.zip
if [ ! -f "$ANTORA_BUNDLE" ]; then
	echo "Cannot find Antora UI Bundle '$ANTORA_BUNDLE'"
	exit 1
fi

# Read component name from antora.yml
COMPONENT=$(yq r /antora/"$ANTORA_PATH"/antora.yml 'name')
echo "Generating Antora documentation for component '$COMPONENT' in file '$ANTORA_FILE'"
echo "Using style: $ANTORA_STYLE"

# Overwrite values in Antora playbook
yq w --inplace /preview/playbook.yml 'site.start_page' "$COMPONENT"::index.adoc
yq w --inplace /preview/playbook.yml 'content.sources[0].start_path' "$ANTORA_PATH"
yq w --inplace /preview/playbook.yml 'ui.bundle.url' "$ANTORA_BUNDLE"

# Generate website
antora --cache-dir=/preview/public/.cache/antora /preview/playbook.yml
cd /preview/public || exit

# Launch Caddy web server
cp /preview/Caddyfile /preview/public/Caddyfile
caddy run

