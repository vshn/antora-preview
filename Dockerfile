FROM docker.io/vshn/antora:3.1.2.2

RUN addgroup -S preview && adduser -S preview -G preview && \
    mkdir -p /preview/bundles && chown -R preview:preview /preview

WORKDIR /preview

# The libnotify requirement courtesy of
# https://github.com/bebraven/platform/pull/82/files
# to fix file system notification issues when running this image in a Mac

RUN set -x && \
    apk update && apk add --no-cache build-base ruby-dev ruby libnotify caddy yq && \
    gem install --no-document guard guard-livereload guard-shell libnotify json && \
    apk del build-base ruby-dev && \
    curl --silent --location https://github.com/appuio/antora-ui-default/releases/download/1.6/ui-bundle.zip -o /preview/bundles/appuio.zip && \
    curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/1.4/ui-bundle.zip -o /preview/bundles/old-syn.zip && \
    curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/2.1.0/ui-bundle.zip -o /preview/bundles/syn.zip && \
    curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/1.8.1/ui-bundle.zip -o /preview/bundles/old-vshn.zip && \
    curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/2.1.1/ui-bundle.zip -o /preview/bundles/vshn.zip && \
    curl --silent --location https://github.com/k8up-io/antora-ui-default/releases/download/1.2.0/ui-bundle.zip -o /preview/bundles/k8up.zip && \
    curl --silent --location https://gitlab.com/antora/antora-ui-default/-/jobs/artifacts/master/raw/build/ui-bundle.zip?job=bundle-stable -o /preview/bundles/antora.zip

COPY antora-preview.sh /usr/local/bin/

USER preview

COPY playbook.yml /preview/playbook.yml
COPY Caddyfile /preview/Caddyfile
COPY Guardfile /preview/Guardfile

EXPOSE 2020
ENTRYPOINT ["antora-preview.sh"]
