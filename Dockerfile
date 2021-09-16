FROM vshn/antora:2.3.3

RUN addgroup -S preview && adduser -S preview -G preview
RUN mkdir -p /preview && chown -R preview:preview /preview

WORKDIR /preview

# The libnotify requirement courtesy of
# https://github.com/bebraven/platform/pull/82/files
# to fix file system notification issues when running this image in a Mac

RUN apk update && apk add unzip build-base ruby-dev libnotify
RUN gem install guard guard-livereload guard-shell libnotify

RUN curl --silent --location https://github.com/mikefarah/yq/releases/download/v4.9.6/yq_linux_amd64 -o /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

RUN curl --silent --location https://github.com/caddyserver/caddy/releases/download/v2.4.2/caddy_2.4.2_linux_amd64.tar.gz -o /preview/caddy.tar.gz
RUN tar -zxvf /preview/caddy.tar.gz
RUN mv /preview/caddy /usr/local/bin/caddy
RUN rm /preview/caddy.tar.gz

RUN mkdir /preview/bundles
RUN curl --silent --location https://github.com/appuio/antora-ui-default/releases/download/1.0/ui-bundle.zip -o /preview/bundles/appuio.zip
RUN curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/1.4/ui-bundle.zip -o /preview/bundles/old-syn.zip
RUN curl --silent --location https://github.com/projectsyn/antora-ui-default/releases/download/2.1.0/ui-bundle.zip -o /preview/bundles/syn.zip
RUN curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/1.8.1/ui-bundle.zip -o /preview/bundles/old-vshn.zip
RUN curl --silent --location https://github.com/vshn/antora-ui-default/releases/download/2.0.14/ui-bundle.zip -o /preview/bundles/vshn.zip
RUN curl --silent --location https://github.com/k8up-io/antora-ui-default/releases/download/1.0.0/ui-bundle.zip -o /preview/bundles/k8up.zip
RUN curl --silent --location https://gitlab.com/antora/antora-ui-default/-/jobs/artifacts/master/raw/build/ui-bundle.zip?job=bundle-stable -o /preview/bundles/antora.zip

COPY antora-preview.sh /usr/local/bin/
COPY signal-listener.sh /usr/local/bin/

USER preview

COPY playbook.yml /preview/playbook.yml
COPY Caddyfile /preview/Caddyfile
COPY Guardfile /preview/Guardfile

EXPOSE 2020
ENTRYPOINT ["signal-listener.sh"]
