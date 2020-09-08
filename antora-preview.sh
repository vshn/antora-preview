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
        echo ""
        echo "Antora Documentation Previewer"
        echo ""
        echo "This command builds an Antora documentation website locally and launches a web server on port 2020 to browse the documentation."
        echo ""
        echo "Arguments:"
        echo "    --style=STYLE / -s=STYLE:"
        echo "           Antora UI Bundle to use to render the documentation."
        echo "           Valid values: 'vshn', 'appuio', 'syn', 'antora'."
        echo "           Default value: 'vshn'"
        echo ""
        echo "    -a=PATH / --antora=PATH:"
        echo "           Path to the subfolder."
        echo "           Default: 'docs'"
        echo ""
        echo "Examples:"
        echo "    antora-preview --style=appuio --antora=src"
        echo ""
        echo "GitHub project: https://github.com/vshn/antora-preview"
        echo ""
        exit 0
    ;;
esac
done

ANTORA_STYLE=${ANTORA_STYLE:-vshn}
ANTORA_PATH=${ANTORA_PATH:-docs}

ANTORA_FILE=/preview/antora/$ANTORA_PATH/antora.yml
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
COMPONENT=$(yq r /preview/antora/"$ANTORA_PATH"/antora.yml 'name')
TITLE=$(yq r /preview/antora/"$ANTORA_PATH"/antora.yml 'title')
echo "===> Generating Antora documentation for component '$TITLE' in file '$ANTORA_FILE'"
echo "===> Using style: $ANTORA_STYLE"
echo ""

# Overwrite values in Antora playbook
yq w --inplace /preview/playbook.yml 'site.start_page' "$COMPONENT"::index.adoc
yq w --inplace /preview/playbook.yml 'site.title' "$TITLE"
yq w --inplace /preview/playbook.yml 'content.sources[0].start_path' "$ANTORA_PATH"
yq w --inplace /preview/playbook.yml 'ui.bundle.url' "$ANTORA_BUNDLE"

# Generate website
antora --cache-dir=/preview/public/.cache/antora /preview/playbook.yml

# Launch Caddy web server
echo ""
echo " _____________________________________________________________________"
echo "|                                                                     |"
echo "| Open http://localhost:2020 in your browser to see the documentation |"
echo "|                                                                     |"
echo "| IMPORTANT! LIVE RELOADING REQUIRES A BROWSER PLUGIN!                |"
echo "| More info here: https://github.com/vshn/antora-preview#livereload   |"
echo "|_____________________________________________________________________|"
echo ""
caddy start
guard --no-interactions --group=documentation
